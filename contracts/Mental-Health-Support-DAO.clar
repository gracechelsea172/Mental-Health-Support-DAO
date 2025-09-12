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