(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-status (err u102))
(define-constant err-unauthorized (err u103))

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
    (asserts! (<= rating u100) (err u104))
    (ok (map-set Reviews
      { shipment-id: shipment-id }
      { rating: rating,
        reviewer: tx-sender,


        timestamp: burn-block-height }))))
(define-read-only (get-driver-stats (driver principal))
  (map-get? Drivers { driver: driver }))

(define-read-only (get-shipment (shipment-id uint))
  (map-get? Shipments { shipment-id: shipment-id }))

(define-read-only (get-route-nft (route-id uint))
  (map-get? RouteNFTs { route-id: route-id }))