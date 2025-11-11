(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-session-not-available (err u105))
(define-constant err-invalid-status (err u106))

(define-constant err-badge-already-earned (err u107))
(define-constant err-badge-not-found (err u108))

(define-constant err-already-claimed (err u109))
(define-constant err-milestone-not-reached (err u110))
(define-constant err-invalid-referral (err u111))


(define-constant err-not-emergency-counselor (err u112))
(define-constant err-emergency-limit-reached (err u113))
(define-constant err-subsidy-depleted (err u114))

(define-data-var emergency-subsidy-pool uint u50000)
(define-data-var emergency-sessions-today uint u0)

(define-fungible-token therapy-token)

(define-data-var next-session-id uint u1)
(define-data-var total-supply uint u1000000)

(define-map counselors principal {
  name: (string-ascii 50),
  specialization: (string-ascii 100),
  rate-per-session: uint,
  total-sessions: uint,
  rating: uint,
  is-active: bool
})

(define-map sessions uint {
  client: principal,
  counselor: principal,
  session-date: uint,
  duration: uint,
  cost: uint,
  status: (string-ascii 20),
  created-at: uint
})

(define-map client-sessions principal (list 50 uint))

(define-map dao-members principal {
  tokens-held: uint,
  voting-power: uint,
  joined-at: uint
})

(define-map proposals uint {
  proposer: principal,
  title: (string-ascii 100),
  description: (string-ascii 500),
  votes-for: uint,
  votes-against: uint,
  status: (string-ascii 20),
  created-at: uint,
  voting-ends: uint
})

(define-data-var next-proposal-id uint u1)

(define-public (register-counselor (name (string-ascii 50)) (specialization (string-ascii 100)) (rate uint))
  (let ((caller tx-sender))
    (asserts! (is-none (map-get? counselors caller)) err-already-exists)
    (map-set counselors caller {
      name: name,
      specialization: specialization,
      rate-per-session: rate,
      total-sessions: u0,
      rating: u50,
      is-active: true
    })
    (ok true)))

(define-public (update-counselor-rate (new-rate uint))
  (let ((counselor-data (unwrap! (map-get? counselors tx-sender) err-not-found)))
    (map-set counselors tx-sender (merge counselor-data { rate-per-session: new-rate }))
    (ok true)))

(define-public (book-session (counselor principal) (session-date uint) (duration uint))
  (let (
    (session-id (var-get next-session-id))
    (counselor-data (unwrap! (map-get? counselors counselor) err-not-found))
    (cost (* (get rate-per-session counselor-data) duration))
    (client-balance (ft-get-balance therapy-token tx-sender))
  )
    (asserts! (get is-active counselor-data) err-unauthorized)
    (asserts! (>= client-balance cost) err-insufficient-funds)
    (try! (ft-transfer? therapy-token cost tx-sender (as-contract tx-sender)))
    (map-set sessions session-id {
      client: tx-sender,
      counselor: counselor,
      session-date: session-date,
      duration: duration,
      cost: cost,
      status: "scheduled",
      created-at: stacks-block-height
    })
    (var-set next-session-id (+ session-id u1))
    (let ((current-sessions (default-to (list) (map-get? client-sessions tx-sender))))
      (map-set client-sessions tx-sender (unwrap! (as-max-len? (append current-sessions session-id) u50) err-not-found)))
    (ok session-id)))

(define-public (complete-session (session-id uint))
  (let ((session-data (unwrap! (map-get? sessions session-id) err-not-found)))
    (asserts! (is-eq tx-sender (get counselor session-data)) err-unauthorized)
    (asserts! (is-eq (get status session-data) "scheduled") err-invalid-status)
    (map-set sessions session-id (merge session-data { status: "completed" }))
    (try! (as-contract (ft-transfer? therapy-token (get cost session-data) tx-sender (get counselor session-data))))
    (let ((counselor-data (unwrap! (map-get? counselors (get counselor session-data)) err-not-found)))
      (map-set counselors (get counselor session-data) 
        (merge counselor-data { total-sessions: (+ (get total-sessions counselor-data) u1) })))
    (ok true)))

(define-public (rate-counselor (counselor principal) (rating uint))
  (let ((counselor-data (unwrap! (map-get? counselors counselor) err-not-found)))
    (asserts! (<= rating u100) err-invalid-status)
    (map-set counselors counselor 
      (merge counselor-data { rating: (/ (+ (* (get rating counselor-data) (get total-sessions counselor-data)) rating) (+ (get total-sessions counselor-data) u1)) }))
    (ok true)))

(define-public (join-dao)
  (let ((current-balance (ft-get-balance therapy-token tx-sender)))
    (asserts! (> current-balance u0) err-insufficient-funds)
    (map-set dao-members tx-sender {
      tokens-held: current-balance,
      voting-power: current-balance,
      joined-at: stacks-block-height
    })
    (ok true)))

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)))
  (let (
    (proposal-id (var-get next-proposal-id))
    (member-data (unwrap! (map-get? dao-members tx-sender) err-unauthorized))
  )
    (asserts! (> (get voting-power member-data) u100) err-unauthorized)
    (map-set proposals proposal-id {
      proposer: tx-sender,
      title: title,
      description: description,
      votes-for: u0,
      votes-against: u0,
      status: "active",
      created-at: stacks-block-height,
      voting-ends: (+ stacks-block-height u1008)
    })
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)))

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let (
    (proposal-data (unwrap! (map-get? proposals proposal-id) err-not-found))
    (member-data (unwrap! (map-get? dao-members tx-sender) err-unauthorized))
    (voting-power (get voting-power member-data))
  )
    (asserts! (is-eq (get status proposal-data) "active") err-invalid-status)
    (asserts! (< stacks-block-height (get voting-ends proposal-data)) err-invalid-status)
    (if vote-for
      (map-set proposals proposal-id (merge proposal-data { votes-for: (+ (get votes-for proposal-data) voting-power) }))
      (map-set proposals proposal-id (merge proposal-data { votes-against: (+ (get votes-against proposal-data) voting-power) })))
    (ok true)))

(define-public (mint-tokens (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ft-mint? therapy-token amount recipient)))

(define-public (cancel-session (session-id uint))
  (let ((session-data (unwrap! (map-get? sessions session-id) err-not-found)))
    (asserts! (is-eq tx-sender (get client session-data)) err-unauthorized)
    (asserts! (is-eq (get status session-data) "scheduled") err-invalid-status)
    (map-set sessions session-id (merge session-data { status: "cancelled" }))
    (as-contract (ft-transfer? therapy-token (get cost session-data) tx-sender (get client session-data)))))

(define-read-only (get-counselor (counselor principal))
  (map-get? counselors counselor))

(define-read-only (get-session (session-id uint))
  (map-get? sessions session-id))

(define-read-only (get-client-sessions (client principal))
  (map-get? client-sessions client))

(define-read-only (get-dao-member (member principal))
  (map-get? dao-members member))

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

(define-read-only (get-token-balance (account principal))
  (ft-get-balance therapy-token account))


(define-map user-badges principal (list 20 (string-ascii 30)))

(define-map badge-registry (string-ascii 30) {
  name: (string-ascii 50),
  description: (string-ascii 100),
  icon: (string-ascii 20),
  requirement: uint
})

(define-data-var next-badge-id uint u1)

(map-set badge-registry "first-session" {
  name: "First Steps",
  description: "Completed your first therapy session",
  icon: "PLANT",
  requirement: u1
})

(map-set badge-registry "consistent-client" {
  name: "Wellness Warrior",
  description: "Completed 5 therapy sessions",
  icon: "STAR",
  requirement: u5
})

(map-set badge-registry "community-supporter" {
  name: "Community Champion",
  description: "Joined the DAO and voted on proposals",
  icon: "SHIELD",
  requirement: u1
})

(define-private (has-badge (user principal) (badge-id (string-ascii 30)))
  (is-some (index-of (default-to (list) (map-get? user-badges user)) badge-id)))

(define-private (count-completed-sessions (client principal))
  (let ((session-ids (default-to (list) (map-get? client-sessions client))))
    (fold check-session-status session-ids u0)))

(define-private (check-session-status (session-id uint) (count uint))
  (match (map-get? sessions session-id)
    session-data (if (is-eq (get status session-data) "completed") (+ count u1) count)
    count))

(define-public (earn-badge (badge-id (string-ascii 30)))
  (let (
    (user tx-sender)
    (badge-data (unwrap! (map-get? badge-registry badge-id) err-badge-not-found))
    (current-badges (default-to (list) (map-get? user-badges user)))
    (completed-sessions (count-completed-sessions user))
    (is-dao-member (is-some (map-get? dao-members user)))
  )
    (asserts! (not (has-badge user badge-id)) err-badge-already-earned)
    (asserts! 
      (or 
        (and (is-eq badge-id "first-session") (>= completed-sessions u1))
        (and (is-eq badge-id "consistent-client") (>= completed-sessions u5))
        (and (is-eq badge-id "community-supporter") is-dao-member)
      ) 
      err-unauthorized)
    (map-set user-badges user 
      (unwrap! (as-max-len? (append current-badges badge-id) u20) err-not-found))
    (ok true)))

(define-read-only (get-user-badges (user principal))
  (map-get? user-badges user))

(define-read-only (get-badge-info (badge-id (string-ascii 30)))
  (map-get? badge-registry badge-id))

(define-read-only (check-badge-eligibility (user principal) (badge-id (string-ascii 30)))
  (let (
    (completed-sessions (count-completed-sessions user))
    (is-dao-member (is-some (map-get? dao-members user)))
    (already-has-badge (has-badge user badge-id))
  )
    {
      eligible: (and 
        (not already-has-badge)
        (or 
          (and (is-eq badge-id "first-session") (>= completed-sessions u1))
          (and (is-eq badge-id "consistent-client") (>= completed-sessions u5))
          (and (is-eq badge-id "community-supporter") is-dao-member)
        )
      ),
      already-earned: already-has-badge,
      sessions-completed: completed-sessions
    }))

(define-map wellness-streaks principal {
  current-streak: uint,
  longest-streak: uint,
  last-session-block: uint,
  milestones-claimed: (list 10 uint)
})

(define-map referrals principal {
  referrer: principal,
  referral-count: uint,
  total-rewards: uint
})

(define-private (calculate-streak (client principal))
  (let (
    (streak-data (default-to { current-streak: u0, longest-streak: u0, last-session-block: u0, milestones-claimed: (list) } 
      (map-get? wellness-streaks client)))
    (session-count (count-completed-sessions client))
  )
    (merge streak-data { current-streak: session-count })))

(define-private (milestone-reward-amount (milestone uint))
  (if (is-eq milestone u3) u50
    (if (is-eq milestone u7) u150
      (if (is-eq milestone u14) u350 u0))))

(define-public (claim-wellness-milestone (milestone uint))
  (let (
    (streak-data (calculate-streak tx-sender))
    (current-streak (get current-streak streak-data))
    (claimed-list (get milestones-claimed streak-data))
    (reward (milestone-reward-amount milestone))
  )
    (asserts! (>= current-streak milestone) err-milestone-not-reached)
    (asserts! (is-none (index-of claimed-list milestone)) err-already-claimed)
    (asserts! (> reward u0) err-invalid-status)
    (map-set wellness-streaks tx-sender 
      (merge streak-data { milestones-claimed: (unwrap! (as-max-len? (append claimed-list milestone) u10) err-not-found) }))
    (as-contract (ft-mint? therapy-token reward tx-sender))))

(define-public (register-referral (referrer principal))
  (let ((existing-referral (map-get? referrals tx-sender)))
    (asserts! (is-none existing-referral) err-already-exists)
    (asserts! (not (is-eq referrer tx-sender)) err-invalid-referral)
    (map-set referrals tx-sender { referrer: referrer, referral-count: u0, total-rewards: u0 })
    (ok true)))

(define-public (process-referral-reward (new-client principal))
  (let (
    (referral-data (unwrap! (map-get? referrals new-client) err-not-found))
    (referrer (get referrer referral-data))
    (referrer-stats (default-to { referrer: tx-sender, referral-count: u0, total-rewards: u0 } (map-get? referrals referrer)))
    (completed (count-completed-sessions new-client))
  )
    (asserts! (is-eq (get referral-count referral-data) u0) err-already-claimed)
    (asserts! (>= completed u1) err-milestone-not-reached)
    (map-set referrals referrer 
      (merge referrer-stats { 
        referral-count: (+ (get referral-count referrer-stats) u1),
        total-rewards: (+ (get total-rewards referrer-stats) u100)
      }))
    (map-set referrals new-client (merge referral-data { referral-count: u1 }))
    (as-contract (ft-mint? therapy-token u100 referrer))))

(define-read-only (get-wellness-streak (client principal))
  (let ((streak-data (calculate-streak client)))
    { current-streak: (get current-streak streak-data),
      longest-streak: (get longest-streak streak-data),
      milestones-claimed: (get milestones-claimed streak-data) }))

(define-read-only (get-referral-stats (user principal))
  (map-get? referrals user))


(define-map emergency-counselors principal {
  available: bool,
  emergency-rate: uint,
  max-daily-emergency: uint,
  total-emergency-sessions: uint,
  current-daily-count: uint,
  last-reset-block: uint
})

(define-private (reset-daily-count-if-needed (counselor principal) (counselor-data {available: bool, emergency-rate: uint, max-daily-emergency: uint, total-emergency-sessions: uint, current-daily-count: uint, last-reset-block: uint}))
  (if (>= (- stacks-block-height (get last-reset-block counselor-data)) u144)
    (merge counselor-data {current-daily-count: u0, last-reset-block: stacks-block-height})
    counselor-data))

(define-public (enable-emergency-sessions (emergency-rate uint) (max-daily uint))
  (let ((counselor-info (unwrap! (map-get? counselors tx-sender) err-not-found)))
    (asserts! (get is-active counselor-info) err-unauthorized)
    (asserts! (>= emergency-rate (* (get rate-per-session counselor-info) u2)) err-invalid-status)
    (map-set emergency-counselors tx-sender {
      available: true,
      emergency-rate: emergency-rate,
      max-daily-emergency: max-daily,
      total-emergency-sessions: u0,
      current-daily-count: u0,
      last-reset-block: stacks-block-height
    })
    (ok true)))

(define-public (book-emergency-session (counselor principal) (duration uint))
  (let (
    (session-id (var-get next-session-id))
    (emergency-data-raw (unwrap! (map-get? emergency-counselors counselor) err-not-emergency-counselor))
    (emergency-data (reset-daily-count-if-needed counselor emergency-data-raw))
    (full-cost (* (get emergency-rate emergency-data) duration))
    (subsidy (/ full-cost u2))
    (client-cost (- full-cost subsidy))
    (client-balance (ft-get-balance therapy-token tx-sender))
    (current-pool (var-get emergency-subsidy-pool))
  )
    (asserts! (get available emergency-data) err-not-emergency-counselor)
    (asserts! (< (get current-daily-count emergency-data) (get max-daily-emergency emergency-data)) err-emergency-limit-reached)
    (asserts! (>= current-pool subsidy) err-subsidy-depleted)
    (asserts! (>= client-balance client-cost) err-insufficient-funds)
    (try! (ft-transfer? therapy-token client-cost tx-sender (as-contract tx-sender)))
    (var-set emergency-subsidy-pool (- current-pool subsidy))
    (map-set sessions session-id {
      client: tx-sender,
      counselor: counselor,
      session-date: stacks-block-height,
      duration: duration,
      cost: full-cost,
      status: "emergency",
      created-at: stacks-block-height
    })
    (var-set next-session-id (+ session-id u1))
    (map-set emergency-counselors counselor 
      (merge emergency-data {
        current-daily-count: (+ (get current-daily-count emergency-data) u1),
        total-emergency-sessions: (+ (get total-emergency-sessions emergency-data) u1)
      }))
    (let ((current-sessions (default-to (list) (map-get? client-sessions tx-sender))))
      (map-set client-sessions tx-sender (unwrap! (as-max-len? (append current-sessions session-id) u50) err-not-found)))
    (ok session-id)))

(define-read-only (get-emergency-counselor (counselor principal))
  (match (map-get? emergency-counselors counselor)
    data (some (reset-daily-count-if-needed counselor data))
    none))

(define-read-only (get-emergency-subsidy-balance)
  (var-get emergency-subsidy-pool))
