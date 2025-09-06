# NFT Rarity Calculator Smart Contract

A comprehensive Clarity smart contract for calculating and managing NFT rarity scores based on trait frequencies. This contract provides a complete solution for NFT collections to track, calculate, and rank their tokens by rarity.

## Overview

The NFT Rarity Calculator enables:
- Multi-collection support with independent rarity calculations
- Dynamic trait frequency tracking
- Weighted rarity score calculations
- Automatic ranking systems
- Batch operations for gas efficiency
- Granular access controls

## Features

### Core Functionality
- **Collection Management**: Initialize and manage multiple NFT collections
- **Trait Tracking**: Register and track trait frequencies across collections
- **Rarity Calculation**: Calculate rarity scores based on trait frequencies and weights
- **Ranking System**: Maintain sorted rankings of NFTs by rarity
- **Batch Operations**: Efficient batch updates for large collections

### Access Control
- **Creator Authorization**: Collection creators have full administrative rights
- **Operator System**: Delegate specific permissions to authorized operators
- **Granular Permissions**: Fine-grained control over who can modify collection data

## Contract Structure

### Data Storage

#### Collections
```clarity
collections: { collection-id: uint } -> {
  name: string-ascii 50,
  total-supply: uint,
  creator: principal,
  is-active: bool
}
```

#### NFT Data
```clarity
nft-data: { collection-id: uint, token-id: uint } -> {
  owner: principal,
  traits: list of trait objects,
  rarity-score: uint,
  rarity-rank: uint,
  last-updated: uint
}
```

#### Trait Frequencies
```clarity
trait-frequencies: { collection-id: uint, trait-type: string, trait-value: string } -> {
  frequency: uint
}
```

### Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR-OWNER-ONLY | Operation restricted to contract owner |
| 101 | ERR-NOT-FOUND | Requested resource not found |
| 102 | ERR-ALREADY-EXISTS | Resource already exists |
| 103 | ERR-INVALID-INPUT | Invalid input parameters |
| 104 | ERR-ZERO-SUPPLY | Collection has zero supply |
| 105 | ERR-TRAIT-NOT-FOUND | Specified trait not found |
| 106 | ERR-UNAUTHORIZED | Insufficient permissions |
| 107 | ERR-INVALID-PRINCIPAL | Invalid principal address |
| 108 | ERR-INVALID-TOKEN-ID | Invalid token identifier |
| 109 | ERR-INVALID-COLLECTION-ID | Invalid collection identifier |

## API Reference

### Initialization Functions

#### `initialize-collection`
Creates a new NFT collection with rarity tracking.

```clarity
(initialize-collection (collection-id uint) (name string-ascii) (total-supply uint))
```

**Parameters:**
- `collection-id`: Unique identifier for the collection
- `name`: Collection name (max 50 characters)
- `total-supply`: Total number of NFTs in collection

**Returns:** `(response uint uint)` - Collection ID on success

#### `add-trait-type`
Registers a new trait type with specified weight for rarity calculations.

```clarity
(add-trait-type (collection-id uint) (trait-type string-ascii) (weight uint))
```

**Parameters:**
- `collection-id`: Target collection identifier
- `trait-type`: Name of the trait type (max 30 characters)
- `weight`: Weight multiplier for rarity calculations

### NFT Management Functions

#### `register-nft`
Registers a new NFT with its traits and calculates initial rarity score.

```clarity
(register-nft (collection-id uint) (token-id uint) (owner principal) (traits list))
```

**Parameters:**
- `collection-id`: Collection identifier
- `token-id`: Unique token identifier
- `owner`: Principal address of NFT owner
- `traits`: List of trait objects (max 20 traits)

**Trait Object Structure:**
```clarity
{ trait-type: string-ascii 30, trait-value: string-ascii 50 }
```

#### `update-nft-traits`
Updates NFT traits and recalculates rarity score and frequencies.

```clarity
(update-nft-traits (collection-id uint) (token-id uint) (new-traits list))
```

### Batch Operations

#### `update-rarity-rankings`
Efficiently updates multiple NFT rankings in a single transaction.

```clarity
(update-rarity-rankings (collection-id uint) (rankings list))
```

**Ranking Object Structure:**
```clarity
{ token-id: uint, rank: uint, score: uint }
```

### Query Functions

#### `get-collection-info`
Retrieves collection metadata.

```clarity
(get-collection-info (collection-id uint))
```

#### `get-nft-data`
Fetches complete NFT data including traits and rarity information.

```clarity
(get-nft-data (collection-id uint) (token-id uint))
```

#### `get-trait-frequency`
Returns frequency count for a specific trait value.

```clarity
(get-trait-frequency (collection-id uint) (trait-type string) (trait-value string))
```

#### `get-trait-rarity-percentage`
Calculates trait rarity as percentage (in basis points).

```clarity
(get-trait-rarity-percentage (collection-id uint) (trait-type string) (trait-value string))
```

#### `calculate-rarity-score`
Computes rarity score for a given set of traits.

```clarity
(calculate-rarity-score (collection-id uint) (traits list))
```

#### `get-rarity-rank`
Retrieves the rarity rank for a specific NFT.

```clarity
(get-rarity-rank (collection-id uint) (token-id uint))
```

#### `get-token-by-rank`
Finds the NFT at a specific rarity rank.

```clarity
(get-token-by-rank (collection-id uint) (rank uint))
```

### Access Control Functions

#### `authorize-operator`
Grants operator permissions to a principal for a collection.

```clarity
(authorize-operator (collection-id uint) (operator principal))
```

#### `revoke-operator`
Removes operator permissions from a principal.

```clarity
(revoke-operator (collection-id uint) (operator principal))
```

#### `is-authorized-operator`
Checks if a principal has operator permissions.

```clarity
(is-authorized-operator (collection-id uint) (operator principal))
```

## Rarity Calculation Algorithm

The contract uses a frequency-based rarity calculation:

1. **Trait Score**: `(total-supply * trait-weight) / trait-frequency`
2. **Total Rarity Score**: Sum of all trait scores for an NFT
3. **Ranking**: NFTs sorted by rarity score (highest = rarest)

### Rarity Percentage
Trait rarity percentage is calculated as:
```
(trait-frequency * 10000) / total-supply
```
Result is in basis points (0-10000, where 10000 = 100%)

## Usage Examples

### Basic Collection Setup

```clarity
;; Initialize collection
(contract-call? .nft-rarity initialize-collection u1 "CoolPunks" u10000)

;; Add trait types with weights
(contract-call? .nft-rarity add-trait-type u1 "Background" u100)
(contract-call? .nft-rarity add-trait-type u1 "Eyes" u150)
(contract-call? .nft-rarity add-trait-type u1 "Hat" u200)
```

### Register NFT with Traits

```clarity
(contract-call? .nft-rarity register-nft 
  u1 
  u1 
  'SP1EXAMPLE...
  (list 
    { trait-type: "Background", trait-value: "Blue" }
    { trait-type: "Eyes", trait-value: "Laser" }
    { trait-type: "Hat", trait-value: "Crown" }
  )
)
```

### Query Rarity Information

```clarity
;; Get NFT rarity rank
(contract-call? .nft-rarity get-rarity-rank u1 u1)

;; Get trait rarity percentage
(contract-call? .nft-rarity get-trait-rarity-percentage u1 "Eyes" "Laser")

;; Find rarest NFT (rank 1)
(contract-call? .nft-rarity get-token-by-rank u1 u1)
```

## Security Considerations

### Input Validation
- All functions validate input parameters for type and range
- Principal addresses are checked against null address
- Token and collection IDs must be within valid uint32 range

### Access Controls
- Collection creators have full administrative rights
- Operators can be authorized for specific collections
- Critical functions require proper authorization

### Gas Optimization
- Batch operations reduce transaction costs
- Efficient data structures minimize storage costs
- Read-only functions for gas-free queries

## Deployment Requirements

### Stacks Blockchain
- Compatible with Clarity 2.0+
- Requires Stacks 2.1+ for full functionality

### Gas Considerations
- Initial collection setup: ~5,000 gas
- NFT registration: ~3,000-8,000 gas (depending on trait count)
- Batch ranking updates: ~500 gas per ranking

## Integration Guidelines

### Frontend Integration
1. Use read-only functions for displaying rarity data
2. Implement batch operations for large collections
3. Cache frequently accessed data to reduce queries

### Backend Services
1. Monitor trait frequency changes
2. Implement ranking calculation services
3. Provide APIs for rarity data access