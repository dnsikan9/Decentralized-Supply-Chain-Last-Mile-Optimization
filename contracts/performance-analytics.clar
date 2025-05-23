;; Performance Analytics Contract
;; Tracks delivery efficiency and carrier performance

(define-data-var admin principal tx-sender)

;; Data structure for carrier performance metrics
(define-map carrier-metrics principal
  {
    total-deliveries: uint,
    on-time-deliveries: uint,
    late-deliveries: uint,
    failed-deliveries: uint,
    average-delivery-time: uint,  ;; in minutes
    total-distance: uint,  ;; in meters
    customer-rating: uint,  ;; out of 100
    last-updated: uint
  }
)

;; Data structure for overall system metrics
(define-data-var system-metrics
  {
    total-packages: uint,
    total-delivered: uint,
    total-in-transit: uint,
    average-delivery-time: uint,  ;; in minutes
    on-time-percentage: uint,  ;; out of 100
    last-updated: uint
  }
  {
    total-packages: u0,
    total-delivered: u0,
    total-in-transit: u0,
    average-delivery-time: u0,
    on-time-percentage: u100,
    last-updated: u0
  }
)

;; Public function to record a delivery completion
(define-public (record-delivery-completion
    (carrier principal)
    (package-id uint)
    (delivery-time uint)
    (distance uint)
    (on-time bool)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1000))

    ;; Update carrier metrics
    (let ((current-metrics (default-to
      {
        total-deliveries: u0,
        on-time-deliveries: u0,
        late-deliveries: u0,
        failed-deliveries: u0,
        average-delivery-time: u0,
        total-distance: u0,
        customer-rating: u0,
        last-updated: u0
      }
      (map-get? carrier-metrics carrier)
    )))
      (map-set carrier-metrics carrier (merge current-metrics
        {
          total-deliveries: (+ (get total-deliveries current-metrics) u1),
          on-time-deliveries: (+ (get on-time-deliveries current-metrics) (if on-time u1 u0)),
          late-deliveries: (+ (get late-deliveries current-metrics) (if on-time u0 u1)),
          average-delivery-time: (calculate-new-average
                                  (get average-delivery-time current-metrics)
                                  (get total-deliveries current-metrics)
                                  delivery-time),
          total-distance: (+ (get total-distance current-metrics) distance),
          last-updated: block-height
        }
      ))
    )

    ;; Update system metrics
    (let ((current-system-metrics (var-get system-metrics)))
      (var-set system-metrics (merge current-system-metrics
        {
          total-delivered: (+ (get total-delivered current-system-metrics) u1),
          total-in-transit: (- (get total-in-transit current-system-metrics) u1),
          average-delivery-time: (calculate-new-average
                                  (get average-delivery-time current-system-metrics)
                                  (get total-delivered current-system-metrics)
                                  delivery-time),
          on-time-percentage: (calculate-new-percentage
                              (get on-time-percentage current-system-metrics)
                              (get total-delivered current-system-metrics)
                              on-time),
          last-updated: block-height
        }
      ))
    )

    (ok true)
  )
)

;; Public function to record a new package registered
(define-public (record-new-package)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1000))
    (let ((current-system-metrics (var-get system-metrics)))
      (var-set system-metrics (merge current-system-metrics
        {
          total-packages: (+ (get total-packages current-system-metrics) u1),
          total-in-transit: (+ (get total-in-transit current-system-metrics) u1),
          last-updated: block-height
        }
      ))
    )
    (ok true)
  )
)

;; Public function to update carrier customer rating
(define-public (update-customer-rating (carrier principal) (rating uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1000))
    (asserts! (<= rating u100) (err u5001))
    (let ((current-metrics (default-to
      {
        total-deliveries: u0,
        on-time-deliveries: u0,
        late-deliveries: u0,
        failed-deliveries: u0,
        average-delivery-time: u0,
        total-distance: u0,
        customer-rating: u0,
        last-updated: u0
      }
      (map-get? carrier-metrics carrier)
    )))
      (ok (map-set carrier-metrics carrier (merge current-metrics
        {
          customer-rating: rating,
          last-updated: block-height
        }
      )))
    )
  )
)

;; Read-only function to get carrier performance metrics
(define-read-only (get-carrier-performance (carrier principal))
  (map-get? carrier-metrics carrier)
)

;; Read-only function to get system metrics
(define-read-only (get-system-metrics)
  (var-get system-metrics)
)

;; Helper function to calculate new average
(define-private (calculate-new-average (current-avg uint) (total-count uint) (new-value uint))
  (if (is-eq total-count u0)
    new-value
    (/ (+ (* current-avg total-count) new-value) (+ total-count u1))
  )
)

;; Helper function to calculate new percentage
(define-private (calculate-new-percentage (current-pct uint) (total-count uint) (is-success bool))
  (if (is-eq total-count u0)
    (if is-success u100 u0)
    (/ (+ (* current-pct total-count) (if is-success u100 u0)) (+ total-count u1))
  )
)

;; Function to transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1000))
    (ok (var-set admin new-admin))
  )
)
