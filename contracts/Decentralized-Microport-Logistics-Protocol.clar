(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-status (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-dispute-exists (err u104))
(define-constant err-dispute-not-found (err u105))
(define-constant err-dispute-resolved (err u106))
(define-constant err-insufficient-funds (err u107))
(define-constant err-escrow-not-found (err u108))
(define-constant err-escrow-released (err u109))

(define-data-var min-reliability-score uint u70)
(define-data-var token-reward-amount uint u100)

(define-map Drivers 
  { driver: principal }
  { reliability-score: uint,
    total-deliveries: uint,
    active: bool,
    tokens-earned: uint }
)

(define-map Shipments
  { shipment-id: uint }
  { sender: principal,
    receiver: principal,
    driver: (optional principal),
    status: (string-ascii 20),
    payment-amount: uint,
    route-tag: uint,
    created-at: uint,
    completed-at: (optional uint) }
)

(define-map RouteNFTs
  { route-id: uint }
  { owner: principal,
    route-hash: (string-ascii 64),
    active: bool }
)

(define-map Reviews
  { shipment-id: uint }
  { rating: uint,
    reviewer: principal,
    timestamp: uint }
)

(define-map Disputes
  { shipment-id: uint }
  { initiator: principal,
    reason: (string-ascii 100),
    status: (string-ascii 20),
    created-at: uint,
    resolved-at: (optional uint),
    resolution: (optional (string-ascii 50)) }
)

(define-map EscrowHoldings
  { shipment-id: uint }
  { amount: uint,
    depositor: principal,
    status: (string-ascii 20),
    created-at: uint,
    released-at: (optional uint) }
)

(define-data-var next-shipment-id uint u1)
(define-data-var next-route-id uint u1)

(define-public (register-driver)
  (let ((driver-data { reliability-score: u100,
                      total-deliveries: u0,
                      active: true,
                      tokens-earned: u0 }))
    (ok (map-set Drivers { driver: tx-sender } driver-data))))

(define-public (create-shipment (receiver principal) (payment-amount uint) (route-hash (string-ascii 64)))
  (let ((shipment-id (var-get next-shipment-id))
        (route-id (var-get next-route-id)))
    (map-set Shipments 
      { shipment-id: shipment-id }
      { sender: tx-sender,
        receiver: receiver,
        driver: none,
        status: "pending",
        payment-amount: payment-amount,
        route-tag: route-id,

        created-at: burn-block-height,
        completed-at: none })
    (map-set RouteNFTs
      { route-id: route-id }
      { owner: tx-sender,
        route-hash: route-hash,
        active: true })
    (var-set next-shipment-id (+ shipment-id u1))
    (var-set next-route-id (+ route-id u1))
    (ok shipment-id)))
(define-public (accept-shipment (shipment-id uint))
  (let ((shipment (unwrap! (map-get? Shipments { shipment-id: shipment-id }) err-not-found))
        (driver (unwrap! (map-get? Drivers { driver: tx-sender }) err-unauthorized)))
    (asserts! (is-eq (get status shipment) "pending") err-invalid-status)
    (ok (map-set Shipments
      { shipment-id: shipment-id }
      (merge shipment { driver: (some tx-sender), status: "in-transit" })))))

(define-public (complete-delivery (shipment-id uint))
  (let ((shipment (unwrap! (map-get? Shipments { shipment-id: shipment-id }) err-not-found))
        (driver (unwrap! (map-get? Drivers { driver: tx-sender }) err-unauthorized)))
    (asserts! (is-eq (get status shipment) "in-transit") err-invalid-status)
    (asserts! (is-eq (some tx-sender) (get driver shipment)) err-unauthorized)
    (map-set Shipments
      { shipment-id: shipment-id }
      (merge shipment { status: "delivered", completed-at: (some burn-block-height) }))
    (map-set Drivers
      { driver: tx-sender }
      (merge driver { total-deliveries: (+ (get total-deliveries driver) u1),
                     tokens-earned: (+ (get tokens-earned driver) (var-get token-reward-amount)) }))
    (ok true)))
(define-public (submit-review (shipment-id uint) (rating uint))
  (let ((shipment (unwrap! (map-get? Shipments { shipment-id: shipment-id }) err-not-found)))
    (asserts! (is-eq (get status shipment) "delivered") err-invalid-status)
    (asserts! (<= rating u100) (err u110))
    (ok (map-set Reviews
      { shipment-id: shipment-id }
      { rating: rating,
        reviewer: tx-sender,


        timestamp: burn-block-height }))))

(define-public (raise-dispute (shipment-id uint) (reason (string-ascii 100)))
  (let ((shipment (unwrap! (map-get? Shipments { shipment-id: shipment-id }) err-not-found))
        (existing-dispute (map-get? Disputes { shipment-id: shipment-id })))
    (asserts! (is-none existing-dispute) err-dispute-exists)
    (asserts! (or (is-eq tx-sender (get sender shipment))
                  (is-eq tx-sender (get receiver shipment))) err-unauthorized)
    (ok (map-set Disputes
      { shipment-id: shipment-id }
      { initiator: tx-sender,
        reason: reason,
        status: "open",
        created-at: burn-block-height,
        resolved-at: none,
        resolution: none }))))

(define-public (resolve-dispute (shipment-id uint) (resolution (string-ascii 50)))
  (let ((dispute (unwrap! (map-get? Disputes { shipment-id: shipment-id }) err-dispute-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (get status dispute) "open") err-dispute-resolved)
    (ok (map-set Disputes
      { shipment-id: shipment-id }
      (merge dispute { status: "resolved",
                      resolved-at: (some burn-block-height),
                      resolution: (some resolution) })))))

(define-read-only (get-dispute (shipment-id uint))
  (map-get? Disputes { shipment-id: shipment-id }))

(define-public (deposit-escrow (shipment-id uint))
  (let ((shipment (unwrap! (map-get? Shipments { shipment-id: shipment-id }) err-not-found))
        (existing-escrow (map-get? EscrowHoldings { shipment-id: shipment-id }))
        (payment-amount (get payment-amount shipment)))
    (asserts! (is-none existing-escrow) err-escrow-released)
    (asserts! (is-eq tx-sender (get sender shipment)) err-unauthorized)
    (asserts! (>= (stx-get-balance tx-sender) payment-amount) err-insufficient-funds)
    (try! (stx-transfer? payment-amount tx-sender (as-contract tx-sender)))
    (ok (map-set EscrowHoldings
      { shipment-id: shipment-id }
      { amount: payment-amount,
        depositor: tx-sender,
        status: "locked",
        created-at: burn-block-height,
        released-at: none }))))

(define-public (release-escrow (shipment-id uint))
  (let ((escrow (unwrap! (map-get? EscrowHoldings { shipment-id: shipment-id }) err-escrow-not-found))
        (shipment (unwrap! (map-get? Shipments { shipment-id: shipment-id }) err-not-found))
        (driver-principal (unwrap! (get driver shipment) err-unauthorized)))
    (asserts! (is-eq (get status shipment) "delivered") err-invalid-status)
    (asserts! (is-eq (get status escrow) "locked") err-escrow-released)
    (as-contract (try! (stx-transfer? (get amount escrow) tx-sender driver-principal)))
    (ok (map-set EscrowHoldings
      { shipment-id: shipment-id }
      (merge escrow { status: "released",
                     released-at: (some burn-block-height) })))))

(define-public (refund-escrow (shipment-id uint))
  (let ((escrow (unwrap! (map-get? EscrowHoldings { shipment-id: shipment-id }) err-escrow-not-found))
        (shipment (unwrap! (map-get? Shipments { shipment-id: shipment-id }) err-not-found))
        (depositor (get depositor escrow)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (get status escrow) "locked") err-escrow-released)
    (as-contract (try! (stx-transfer? (get amount escrow) tx-sender depositor)))
    (ok (map-set EscrowHoldings
      { shipment-id: shipment-id }
      (merge escrow { status: "refunded",
                     released-at: (some burn-block-height) })))))

(define-read-only (get-escrow-status (shipment-id uint))
  (map-get? EscrowHoldings { shipment-id: shipment-id }))
(define-read-only (get-driver-stats (driver principal))
  (map-get? Drivers { driver: driver }))

(define-read-only (get-shipment (shipment-id uint))
  (map-get? Shipments { shipment-id: shipment-id }))

(define-read-only (get-route-nft (route-id uint))
  (map-get? RouteNFTs { route-id: route-id }))