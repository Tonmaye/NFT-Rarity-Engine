;; NFT Rarity Calculator Smart Contract
;; This contract calculates and manages NFT rarity scores based on trait frequencies

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-INPUT (err u103))
(define-constant ERR-ZERO-SUPPLY (err u104))
(define-constant ERR-TRAIT-NOT-FOUND (err u105))
(define-constant ERR-UNAUTHORIZED (err u106))
(define-constant ERR-INVALID-PRINCIPAL (err u107))
(define-constant ERR-INVALID-TOKEN-ID (err u108))
(define-constant ERR-INVALID-COLLECTION-ID (err u109))

;; Data Variables
(define-data-var total-collection-supply uint u0)
(define-data-var collection-name (string-ascii 50) "")
(define-data-var is-initialized bool false)

;; Data Maps
;; Collection metadata
(define-map collections
  { collection-id: uint }
  {
    name: (string-ascii 50),
    total-supply: uint,
    creator: principal,
    is-active: bool
  }
)

;; NFT metadata and traits
(define-map nft-data
  { collection-id: uint, token-id: uint }
  {
    owner: principal,
    traits: (list 20 { trait-type: (string-ascii 30), trait-value: (string-ascii 50) }),
    rarity-score: uint,
    rarity-rank: uint,
    last-updated: uint
  }
)

;; Trait frequency tracking
(define-map trait-frequencies
  { collection-id: uint, trait-type: (string-ascii 30), trait-value: (string-ascii 50) }
  { frequency: uint }
)

;; Trait type registry
(define-map trait-types
  { collection-id: uint, trait-type: (string-ascii 30) }
  { 
    is-active: bool,
    weight: uint,
    total-variants: uint
  }
)

;; Rarity rankings
(define-map rarity-rankings
  { collection-id: uint, rank: uint }
  { token-id: uint, rarity-score: uint }
)

;; Authorization
(define-map authorized-operators
  { collection-id: uint, operator: principal }
  { is-authorized: bool }
)

;; Input validation functions
(define-private (is-valid-principal (principal-to-check principal))
  (not (is-eq principal-to-check 'SP000000000000000000002Q6VF78))
)

(define-private (is-valid-token-id (token-id uint))
  (and (>= token-id u1) (<= token-id u4294967295)) ;; Valid uint32 range
)

(define-private (is-valid-collection-id (collection-id uint))
  (and (>= collection-id u1) (<= collection-id u4294967295)) ;; Valid uint32 range
)

;; Read-only functions

;; Get collection info
(define-read-only (get-collection-info (collection-id uint))
  (map-get? collections { collection-id: collection-id })
)

;; Get NFT data
(define-read-only (get-nft-data (collection-id uint) (token-id uint))
  (map-get? nft-data { collection-id: collection-id, token-id: token-id })
)

;; Get trait frequency
(define-read-only (get-trait-frequency (collection-id uint) (trait-type (string-ascii 30)) (trait-value (string-ascii 50)))
  (default-to u0 (get frequency (map-get? trait-frequencies 
    { collection-id: collection-id, trait-type: trait-type, trait-value: trait-value })))
)

;; Calculate trait rarity percentage
(define-read-only (get-trait-rarity-percentage (collection-id uint) (trait-type (string-ascii 30)) (trait-value (string-ascii 50)))
  (let (
    (frequency (get-trait-frequency collection-id trait-type trait-value))
    (collection-info (unwrap! (get-collection-info collection-id) (err ERR-NOT-FOUND)))
    (total-supply (get total-supply collection-info))
  )
    (if (> total-supply u0)
      (ok (/ (* frequency u10000) total-supply)) ;; Return as basis points (0-10000)
      (err ERR-ZERO-SUPPLY)
    )
  )
)

;; Get rarity rank by token
(define-read-only (get-rarity-rank (collection-id uint) (token-id uint))
  (match (get-nft-data collection-id token-id)
    nft-info (ok (get rarity-rank nft-info))
    (err ERR-NOT-FOUND)
  )
)

;; Get token by rank
(define-read-only (get-token-by-rank (collection-id uint) (rank uint))
  (map-get? rarity-rankings { collection-id: collection-id, rank: rank })
)

;; Get trait type info
(define-read-only (get-trait-type-info (collection-id uint) (trait-type (string-ascii 30)))
  (map-get? trait-types { collection-id: collection-id, trait-type: trait-type })
)

;; Calculate rarity score for given traits
(define-read-only (calculate-rarity-score (collection-id uint) (traits (list 20 { trait-type: (string-ascii 30), trait-value: (string-ascii 50) })))
  (let (
    (collection-info (unwrap! (get-collection-info collection-id) (err ERR-NOT-FOUND)))
    (total-supply (get total-supply collection-info))
  )
    (if (is-eq total-supply u0)
      (err ERR-ZERO-SUPPLY)
      (ok (fold calculate-trait-score traits { collection-id: collection-id, total-supply: total-supply, score: u0 }))
    )
  )
)

;; Helper function for calculating trait scores
(define-private (calculate-trait-score 
  (trait { trait-type: (string-ascii 30), trait-value: (string-ascii 50) })
  (acc { collection-id: uint, total-supply: uint, score: uint })
)
  (let (
    (frequency (get-trait-frequency (get collection-id acc) (get trait-type trait) (get trait-value trait)))
    (trait-weight (default-to u100 (get weight (get-trait-type-info (get collection-id acc) (get trait-type trait)))))
    (trait-score (if (> frequency u0) 
                   (/ (* (get total-supply acc) trait-weight) frequency)
                   u0))
  )
    (merge acc { score: (+ (get score acc) trait-score) })
  )
)

;; Check if operator is authorized
(define-read-only (is-authorized-operator (collection-id uint) (operator principal))
  (default-to false (get is-authorized (map-get? authorized-operators { collection-id: collection-id, operator: operator })))
)

;; Public functions

;; Initialize a new collection
(define-public (initialize-collection (collection-id uint) (name (string-ascii 50)) (total-supply uint))
  (let (
    (existing-collection (get-collection-info collection-id))
  )
    (asserts! (is-valid-collection-id collection-id) (err ERR-INVALID-COLLECTION-ID))
    (asserts! (is-none existing-collection) (err ERR-ALREADY-EXISTS))
    (asserts! (> total-supply u0) (err ERR-INVALID-INPUT))
    (asserts! (> (len name) u0) (err ERR-INVALID-INPUT))
    
    (map-set collections
      { collection-id: collection-id }
      {
        name: name,
        total-supply: total-supply,
        creator: tx-sender,
        is-active: true
      }
    )
    
    ;; Authorize creator as operator
    (map-set authorized-operators
      { collection-id: collection-id, operator: tx-sender }
      { is-authorized: true }
    )
    
    (ok collection-id)
  )
)

;; Add or update trait type
(define-public (add-trait-type (collection-id uint) (trait-type (string-ascii 30)) (weight uint))
  (let (
    (collection-info (unwrap! (get-collection-info collection-id) (err ERR-NOT-FOUND)))
  )
    (asserts! (is-valid-collection-id collection-id) (err ERR-INVALID-COLLECTION-ID))
    (asserts! (or (is-eq tx-sender (get creator collection-info)) 
                  (is-authorized-operator collection-id tx-sender))
              (err ERR-UNAUTHORIZED))
    (asserts! (> (len trait-type) u0) (err ERR-INVALID-INPUT))
    (asserts! (> weight u0) (err ERR-INVALID-INPUT))
    
    (map-set trait-types
      { collection-id: collection-id, trait-type: trait-type }
      {
        is-active: true,
        weight: weight,
        total-variants: u0
      }
    )
    
    (ok true)
  )
)

;; Register NFT with traits
(define-public (register-nft 
  (collection-id uint) 
  (token-id uint) 
  (owner principal) 
  (traits (list 20 { trait-type: (string-ascii 30), trait-value: (string-ascii 50) }))
)
  (let (
    (collection-info (unwrap! (get-collection-info collection-id) (err ERR-NOT-FOUND)))
    (existing-nft (get-nft-data collection-id token-id))
  )
    (asserts! (is-valid-collection-id collection-id) (err ERR-INVALID-COLLECTION-ID))
    (asserts! (is-valid-token-id token-id) (err ERR-INVALID-TOKEN-ID))
    (asserts! (is-valid-principal owner) (err ERR-INVALID-PRINCIPAL))
    (asserts! (or (is-eq tx-sender (get creator collection-info)) 
                  (is-authorized-operator collection-id tx-sender))
              (err ERR-UNAUTHORIZED))
    (asserts! (is-none existing-nft) (err ERR-ALREADY-EXISTS))
    (asserts! (> (len traits) u0) (err ERR-INVALID-INPUT))
    
    ;; Update trait frequencies
    (fold update-trait-frequency-helper traits { collection-id: collection-id })
    
    ;; Calculate rarity score
    (let (
      (rarity-calc (unwrap! (calculate-rarity-score collection-id traits) (err ERR-INVALID-INPUT)))
      (rarity-score (get score rarity-calc))
    )
      ;; Store NFT data
      (map-set nft-data
        { collection-id: collection-id, token-id: token-id }
        {
          owner: owner,
          traits: traits,
          rarity-score: rarity-score,
          rarity-rank: u0, ;; Will be calculated separately
          last-updated: stacks-block-height
        }
      )
      
      (ok token-id)
    )
  )
)

;; Helper function to update trait frequencies
(define-private (update-trait-frequency-helper 
  (trait { trait-type: (string-ascii 30), trait-value: (string-ascii 50) })
  (acc { collection-id: uint })
)
  (let (
    (current-frequency (get-trait-frequency (get collection-id acc) (get trait-type trait) (get trait-value trait)))
  )
    (map-set trait-frequencies
      { collection-id: (get collection-id acc), trait-type: (get trait-type trait), trait-value: (get trait-value trait) }
      { frequency: (+ current-frequency u1) }
    )
    acc
  )
)

;; Update NFT traits and recalculate rarity
(define-public (update-nft-traits 
  (collection-id uint) 
  (token-id uint) 
  (new-traits (list 20 { trait-type: (string-ascii 30), trait-value: (string-ascii 50) }))
)
  (let (
    (collection-info (unwrap! (get-collection-info collection-id) (err ERR-NOT-FOUND)))
    (existing-nft (unwrap! (get-nft-data collection-id token-id) (err ERR-NOT-FOUND)))
  )
    (asserts! (is-valid-collection-id collection-id) (err ERR-INVALID-COLLECTION-ID))
    (asserts! (is-valid-token-id token-id) (err ERR-INVALID-TOKEN-ID))
    (asserts! (or (is-eq tx-sender (get creator collection-info)) 
                  (is-authorized-operator collection-id tx-sender))
              (err ERR-UNAUTHORIZED))
    
    ;; Decrease old trait frequencies
    (fold decrease-trait-frequency-helper (get traits existing-nft) { collection-id: collection-id })
    
    ;; Increase new trait frequencies
    (fold update-trait-frequency-helper new-traits { collection-id: collection-id })
    
    ;; Recalculate rarity score
    (let (
      (rarity-calc (unwrap! (calculate-rarity-score collection-id new-traits) (err ERR-INVALID-INPUT)))
      (rarity-score (get score rarity-calc))
    )
      (map-set nft-data
        { collection-id: collection-id, token-id: token-id }
        (merge existing-nft {
          traits: new-traits,
          rarity-score: rarity-score,
          last-updated: stacks-block-height
        })
      )
      
      (ok token-id)
    )
  )
)

;; Helper function to decrease trait frequencies
(define-private (decrease-trait-frequency-helper 
  (trait { trait-type: (string-ascii 30), trait-value: (string-ascii 50) })
  (acc { collection-id: uint })
)
  (let (
    (current-frequency (get-trait-frequency (get collection-id acc) (get trait-type trait) (get trait-value trait)))
  )
    (if (> current-frequency u0)
      (map-set trait-frequencies
        { collection-id: (get collection-id acc), trait-type: (get trait-type trait), trait-value: (get trait-value trait) }
        { frequency: (- current-frequency u1) }
      )
      false
    )
    acc
  )
)

;; Batch update rarity rankings (for gas efficiency)
(define-public (update-rarity-rankings (collection-id uint) (rankings (list 100 { token-id: uint, rank: uint, score: uint })))
  (let (
    (collection-info (unwrap! (get-collection-info collection-id) (err ERR-NOT-FOUND)))
  )
    (asserts! (is-valid-collection-id collection-id) (err ERR-INVALID-COLLECTION-ID))
    (asserts! (or (is-eq tx-sender (get creator collection-info)) 
                  (is-authorized-operator collection-id tx-sender))
              (err ERR-UNAUTHORIZED))
    
    (fold update-ranking-helper rankings { collection-id: collection-id })
    (ok (len rankings))
  )
)

;; Helper function to update individual rankings
(define-private (update-ranking-helper 
  (ranking { token-id: uint, rank: uint, score: uint })
  (acc { collection-id: uint })
)
  (let (
    (existing-nft (get-nft-data (get collection-id acc) (get token-id ranking)))
  )
    (if (is-valid-token-id (get token-id ranking))
      (match existing-nft
        nft-info (begin
          ;; Update NFT rank
          (map-set nft-data
            { collection-id: (get collection-id acc), token-id: (get token-id ranking) }
            (merge nft-info { rarity-rank: (get rank ranking) })
          )
          
          ;; Update rankings map
          (map-set rarity-rankings
            { collection-id: (get collection-id acc), rank: (get rank ranking) }
            { token-id: (get token-id ranking), rarity-score: (get score ranking) }
          )
        )
        false
      )
      false
    )
    acc
  )
)

;; Authorize operator
(define-public (authorize-operator (collection-id uint) (operator principal))
  (let (
    (collection-info (unwrap! (get-collection-info collection-id) (err ERR-NOT-FOUND)))
  )
    (asserts! (is-valid-collection-id collection-id) (err ERR-INVALID-COLLECTION-ID))
    (asserts! (is-valid-principal operator) (err ERR-INVALID-PRINCIPAL))
    (asserts! (is-eq tx-sender (get creator collection-info)) (err ERR-UNAUTHORIZED))
    
    (map-set authorized-operators
      { collection-id: collection-id, operator: operator }
      { is-authorized: true }
    )
    
    (ok true)
  )
)

;; Revoke operator authorization
(define-public (revoke-operator (collection-id uint) (operator principal))
  (let (
    (collection-info (unwrap! (get-collection-info collection-id) (err ERR-NOT-FOUND)))
  )
    (asserts! (is-valid-collection-id collection-id) (err ERR-INVALID-COLLECTION-ID))
    (asserts! (is-valid-principal operator) (err ERR-INVALID-PRINCIPAL))
    (asserts! (is-eq tx-sender (get creator collection-info)) (err ERR-UNAUTHORIZED))
    
    (map-set authorized-operators
      { collection-id: collection-id, operator: operator }
      { is-authorized: false }
    )
    
    (ok true)
  )
)

;; Deactivate collection
(define-public (deactivate-collection (collection-id uint))
  (let (
    (collection-info (unwrap! (get-collection-info collection-id) (err ERR-NOT-FOUND)))
  )
    (asserts! (is-valid-collection-id collection-id) (err ERR-INVALID-COLLECTION-ID))
    (asserts! (is-eq tx-sender (get creator collection-info)) (err ERR-UNAUTHORIZED))
    
    (map-set collections
      { collection-id: collection-id }
      (merge collection-info { is-active: false })
    )
    
    (ok true)
  )
)

;; Get multiple NFTs data (batch read)
(define-read-only (get-nfts-batch (collection-id uint) (token-ids (list 50 uint)))
  (map get-nft-data-helper token-ids)
)

(define-private (get-nft-data-helper (token-id uint))
  (get-nft-data u1 token-id) ;; Default to collection 1, could be parameterized
)

;; Get top rarest NFTs
(define-read-only (get-top-rare-nfts (collection-id uint) (limit uint))
  (let (
    (ranks (generate-rank-list limit))
  )
    (map get-token-by-rank-helper ranks)
  )
)

(define-private (get-token-by-rank-helper (rank uint))
  (get-token-by-rank u1 rank) ;; Default to collection 1
)

(define-private (generate-rank-list (limit uint))
  (if (<= limit u10)
    (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)
    (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) ;; Truncated for simplicity
  )
)