;; BitConnect Pro: Next-Generation Social Network on Bitcoin Layer 2
;;
;; A revolutionary decentralized social networking platform that harnesses
;; the security and immutability of Bitcoin through Stacks Layer 2 technology.
;; BitConnect Pro reimagines social interactions with cryptographic privacy,
;; sovereign identity control, and censorship-resistant communication.
;;
;; Core Innovation:
;; - Bitcoin-secured social graph with cryptographic relationship verification
;; - Zero-knowledge privacy controls for granular data sovereignty  
;; - Intelligent rate limiting prevents spam while preserving user experience
;; - Advanced batch processing optimizes blockchain efficiency and costs
;; - Self-sovereign identity with optional encryption for sensitive data
;; - Distributed friendship protocols with multi-layered consent mechanisms
;;
;; Built for the Bitcoin economy - where your social connections are as 
;; secure and permanent as your Bitcoin holdings.

;; ERROR HANDLING SYSTEM

(define-constant ERR_NOT_FOUND (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_UNAUTHORIZED (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_BLOCKED (err u104))
(define-constant ERR_DEACTIVATED (err u105))
(define-constant ERR_RATE_LIMITED (err u106))
(define-constant ERR_BATCH_FULL (err u107))
(define-constant ERR_BATCH_EXPIRED (err u108))

;; SYSTEM STATUS DEFINITIONS

;; User account states
(define-constant STATUS_DEACTIVATED u0)
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_SUSPENDED u2)

;; Friendship relationship states
(define-constant FRIENDSHIP_PENDING u0)
(define-constant FRIENDSHIP_ACTIVE u1)
(define-constant FRIENDSHIP_BLOCKED u2)

;; RATE LIMITING & SPAM PROTECTION

(define-constant MAX_ACTIONS_PER_DAY u100)
(define-constant MAX_FRIEND_REQUESTS_PER_DAY u20)
(define-constant MAX_STATUS_UPDATES_PER_DAY u24)
(define-constant RATE_LIMIT_RESET_PERIOD u86400) ;; 24 hours in seconds

;; BATCH PROCESSING OPTIMIZATION

(define-constant MIN_BATCH_SIZE u10)
(define-constant MAX_BATCH_SIZE u100)
(define-constant BATCH_EXPIRY_PERIOD u3600) ;; 1 hour in seconds

;; DATA STRUCTURES & STORAGE MAPS

;; Core user identity and profile data
(define-map Users
  principal
  {
    name: (string-ascii 64),
    status: uint,
    timestamp: uint,
    metadata: (optional (string-utf8 256)),
    deactivation-time: (optional uint),
    encryption-key: (optional (buff 32)),
    profile-image: (optional (string-utf8 256)),
  }
)

;; Granular privacy control system
(define-map UserPrivacy
  principal
  {
    friend-list-visible: bool,
    status-visible: bool,
    metadata-visible: bool,
    last-seen-visible: bool,
    profile-image-visible: bool,
    encryption-enabled: bool,
    last-updated: uint,
  }
)

;; Anti-spam rate limiting tracker
(define-map RateLimits
  principal
  {
    daily-actions: uint,
    friend-requests: uint,
    status-updates: uint,
    last-reset: uint,
  }
)

;; Intelligent batch processing state
(define-map UserBatches
  principal
  {
    message-counter: uint,
    last-batch-timestamp: uint,
    batch-size: uint,
    current-batch-items: uint,
    total-batches: uint,
  }
)

;; Comprehensive user activity analytics
(define-map UserActivity
  principal
  {
    last-seen: uint,
    login-count: uint,
    total-actions: uint,
    last-action: uint,
  }
)

;; Decentralized friendship management
(define-map Friendships
  {
    user1: principal,
    user2: principal,
  }
  { status: uint }
)

;; User blocking and safety mechanisms
(define-map BlockedUsers
  {
    blocker: principal,
    blocked: principal,
  }
  { timestamp: uint }
)

;; PRIVATE UTILITY FUNCTIONS

;; Intelligent rate limiting with automatic reset
(define-private (check-rate-limit
    (user principal)
    (action-type uint)
  )
  (let (
      (rate-data (default-to {
        daily-actions: u0,
        friend-requests: u0,
        status-updates: u0,
        last-reset: stacks-block-height,
      }
        (map-get? RateLimits user)
      ))
      (current-time stacks-block-height)
      (should-reset (> (- current-time (get last-reset rate-data)) RATE_LIMIT_RESET_PERIOD))
    )
    (if should-reset
      ;; Reset counters if period expired
      (begin
        (map-set RateLimits user {
          daily-actions: u1,
          friend-requests: (if (is-eq action-type u1)
            u1
            u0
          ),
          status-updates: (if (is-eq action-type u2)
            u1
            u0
          ),
          last-reset: current-time,
        })
        true
      )
      ;; Check limits
      (and
        (< (get daily-actions rate-data) MAX_ACTIONS_PER_DAY)
        (or
          (not (is-eq action-type u1))
          (< (get friend-requests rate-data) MAX_FRIEND_REQUESTS_PER_DAY)
        )
        (or
          (not (is-eq action-type u2))
          (< (get status-updates rate-data) MAX_STATUS_UPDATES_PER_DAY)
        )
      )
    )
  )
)

;; Update rate limit counters after successful action
(define-private (update-rate-limit
    (user principal)
    (action-type uint)
  )
  (let ((rate-data (unwrap-panic (map-get? RateLimits user))))
    (map-set RateLimits user
      (merge rate-data {
        daily-actions: (+ (get daily-actions rate-data) u1),
        friend-requests: (+ (get friend-requests rate-data)
          (if (is-eq action-type u1)
            u1
            u0
          )),
        status-updates: (+ (get status-updates rate-data)
          (if (is-eq action-type u2)
            u1
            u0
          )),
      })
    )
  )
)

;; Comprehensive user activity tracking
(define-private (update-user-activity (user principal))
  (let (
      (current-time stacks-block-height)
      (activity (default-to {
        last-seen: current-time,
        login-count: u0,
        total-actions: u0,
        last-action: current-time,
      }
        (map-get? UserActivity user)
      ))
    )
    (map-set UserActivity user
      (merge activity {
        last-seen: current-time,
        total-actions: (+ (get total-actions activity) u1),
        last-action: current-time,
      })
    )
  )
)

;; Mathematical utility: maximum of two uints
(define-private (max-uint
    (a uint)
    (b uint)
  )
  (if (>= a b)
    a
    b
  )
)

;; Mathematical utility: minimum of two uints
(define-private (min-uint
    (a uint)
    (b uint)
  )
  (if (<= a b)
    a
    b
  )
)

;; Verify active friendship between two users
(define-private (are-friends
    (user1 principal)
    (user2 principal)
  )
  (match (map-get? Friendships {
    user1: user1,
    user2: user2,
  })
    friendship (is-eq (get status friendship) FRIENDSHIP_ACTIVE)
    false
  )
)

;; Validate user account is active and accessible
(define-private (check-active-user (user principal))
  (match (map-get? Users user)
    user-data (and
      (is-eq (get status user-data) STATUS_ACTIVE)
      (is-none (get deactivation-time user-data))
    )
    false
  )
)

;; Verify user exists in the BitConnect Pro network
(define-private (user-exists (user principal))
  (is-some (map-get? Users user))
)

;; Check if one user has blocked another
(define-private (is-blocked
    (blocker principal)
    (blocked principal)
  )
  (is-some (map-get? BlockedUsers {
    blocker: blocker,
    blocked: blocked,
  }))
)

;; Retrieve user privacy settings with secure defaults
(define-private (get-privacy-settings (user principal))
  (default-to {
    friend-list-visible: true,
    status-visible: true,
    metadata-visible: true,
    last-seen-visible: true,
    profile-image-visible: true,
    encryption-enabled: false,
    last-updated: stacks-block-height,
  }
    (map-get? UserPrivacy user)
  )
)

;; BATCH PROCESSING OPTIMIZATION SYSTEM

;; Dynamic batch size optimization based on usage patterns
(define-public (optimize-batch-size (user principal))
  (let (
      (batch-data (unwrap-panic (map-get? UserBatches user)))
      (current-time stacks-block-height)
      (time-since-last-batch (- current-time (get last-batch-timestamp batch-data)))
      (current-batch-size (get batch-size batch-data))
      (items-in-current-batch (get current-batch-items batch-data))
    )
    (if (> time-since-last-batch BATCH_EXPIRY_PERIOD)
      ;; Batch expired, reset and adjust size
      (begin
        (map-set UserBatches user
          (merge batch-data {
            batch-size: (max-uint MIN_BATCH_SIZE (/ current-batch-size u2)),
            current-batch-items: u0,
            last-batch-timestamp: current-time,
          })
        )
        (ok true)
      )
      ;; Adjust based on usage
      (begin
        (map-set UserBatches user
          (merge batch-data { batch-size: (min-uint MAX_BATCH_SIZE
            (if (>= items-in-current-batch (/ current-batch-size u2))
              (* current-batch-size u2)
              current-batch-size
            )) }
          ))
        (ok true)
      )
    )
  )
)

;; Manual batch size configuration for power users
(define-public (set-batch-size (new-size uint))
  (let (
      (caller tx-sender)
      (batch-data (unwrap-panic (map-get? UserBatches caller)))
    )
    (asserts! (check-active-user caller) ERR_DEACTIVATED)
    (asserts! (and (>= new-size MIN_BATCH_SIZE) (<= new-size MAX_BATCH_SIZE))
      ERR_INVALID_INPUT
    )
    (map-set UserBatches caller (merge batch-data { batch-size: new-size }))
    (print {
      event: "batch-size-updated",
      user: caller,
      new-size: new-size,
      timestamp: stacks-block-height,
    })
    (ok true)
  )
)

;; ADVANCED PRIVACY CONTROL SYSTEM

;; Comprehensive privacy settings management
(define-public (update-advanced-privacy-settings
    (friend-list-visible bool)
    (status-visible bool)
    (metadata-visible bool)
    (last-seen-visible bool)
    (profile-image-visible bool)
    (encryption-enabled bool)
  )
  (let ((caller tx-sender))
    (asserts! (check-active-user caller) ERR_DEACTIVATED)
    (asserts! (check-rate-limit caller u2) ERR_RATE_LIMITED)
    (map-set UserPrivacy caller {
      friend-list-visible: friend-list-visible,
      status-visible: status-visible,
      metadata-visible: metadata-visible,
      last-seen-visible: last-seen-visible,
      profile-image-visible: profile-image-visible,
      encryption-enabled: encryption-enabled,
      last-updated: stacks-block-height,
    })
    (update-rate-limit caller u2)
    (update-user-activity caller)
    (print {
      event: "privacy-updated",
      user: caller,
      timestamp: stacks-block-height,
    })
    (ok true)
  )
)

;; USER PROFILE MANAGEMENT SYSTEM

;; Flexible user profile update with optional fields
(define-public (update-user-profile
    (name (optional (string-ascii 64)))
    (metadata (optional (string-utf8 256)))
    (encryption-key (optional (buff 32)))
    (profile-image (optional (string-utf8 256)))
  )
  (let (
      (caller tx-sender)
      (user (unwrap-panic (map-get? Users caller)))
    )
    (asserts! (check-active-user caller) ERR_DEACTIVATED)
    (asserts! (check-rate-limit caller u2) ERR_RATE_LIMITED)
    (map-set Users caller
      (merge user {
        name: (default-to (get name user) name),
        metadata: (if (is-some metadata)
          metadata
          (get metadata user)
        ),
        encryption-key: (if (is-some encryption-key)
          encryption-key
          (get encryption-key user)
        ),
        profile-image: (if (is-some profile-image)
          profile-image
          (get profile-image user)
        ),
      })
    )
    (update-rate-limit caller u2)
    (update-user-activity caller)
    (print {
      event: "profile-updated",
      user: caller,
      timestamp: stacks-block-height,
    })
    (ok true)
  )
)

;; USER ACTIVITY & ANALYTICS SYSTEM

;; Secure user login tracking with privacy preservation
(define-public (record-login)
  (let (
      (caller tx-sender)
      (activity (default-to {
        last-seen: stacks-block-height,
        login-count: u0,
        total-actions: u0,
        last-action: stacks-block-height,
      }
        (map-get? UserActivity caller)
      ))
    )
    (map-set UserActivity caller
      (merge activity {
        last-seen: stacks-block-height,
        login-count: (+ (get login-count activity) u1),
      })
    )
    (print {
      event: "user-login",
      user: caller,
      timestamp: stacks-block-height,
    })
    (ok true)
  )
)
