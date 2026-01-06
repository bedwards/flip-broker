# Flip Broker - AI Agent Instructions

## Project Overview

Flip Broker is a **marketplace arbitrage platform** that finds underpriced items on Facebook Marketplace and lists them on eBay at their true national market value. We use ML to identify arbitrage opportunities and expand sellers' reach from local to nationwide.

## Business Model

```
LOCAL FB PRICE           FLIP BROKER              NATIONAL EBAY VALUE
(limited buyers)    →    (ML pricing +       →    (nationwide demand)
                          smart filtering)

Seller gets: Their full asking price
Buyer gets: Access to local deals they'd never find
We get: The spread between local and national prices
```

**Key Principles:**
- We ALWAYS pay sellers their full asking price (never negotiate down)
- We NEVER budge on our eBay listing price (no negotiation)
- We expand reach: local listings → nationwide shipping
- We only list items we're confident about (skip unknowns)

## Core Pipeline

### 1. FB Marketplace Scraping
- Residential proxies for anti-detection
- All categories, $20+ items
- Extract: title, description, photos, price, location, seller

### 2. Analysis Pipeline
```
FB Listing → Keyword Extraction → Image Similarity → UPC/Barcode OCR
                                         ↓
                              LLM Interpretation
                                         ↓
                            eBay Comparable Matching
```

### 3. Pricing Intelligence (ML)
- **Training data**: Hybrid (eBay sold listings API + own accumulated data)
- **Output**: Predicted national market value
- **Confidence scoring**: Skip items model isn't confident about

### 4. Filtering Gates
```
┌─────────────────────────────────────────────────────────────┐
│ GATE 1: Arbitrage Spread                                     │
│   Dynamic threshold:                                         │
│   - Cheap items ($20-50): Need 30%+ spread                  │
│   - Mid items ($50-200): Need 20%+ spread                   │
│   - Expensive ($200+): Need 15%+ spread                     │
├─────────────────────────────────────────────────────────────┤
│ GATE 2: Shippability                                         │
│   - Size: Fits standard shipping boxes                       │
│   - Weight: Under 70 lbs                                     │
│   - Cost ratio: Shipping < 20% of item value                │
│   - Category: No furniture, cars, large appliances          │
├─────────────────────────────────────────────────────────────┤
│ GATE 3: Scam Detection                                       │
│   Combination scoring - multiple red flags = skip:           │
│   - Price < 50% of market value                             │
│   - New seller account                                       │
│   - Stock/stolen photos                                      │
│   - Urgency language ("must sell today")                    │
│   - Vague description, no real photos                       │
├─────────────────────────────────────────────────────────────┤
│ GATE 4: Model Confidence                                     │
│   - High confidence: Auto-list                              │
│   - Low confidence: Skip (don't list unknowns)              │
└─────────────────────────────────────────────────────────────┘
```

### 5. eBay Listing
- **Price**: ML-predicted national value (NOT FB price + fixed markup)
- **Handling time**: Extended (5-7 days)
- **Payment**: Immediate payment required
- **Buyers**: Buyer requirements enforced (feedback, no unpaid items)
- **Ship-from**: FB seller's city (approximate)
- **Negotiation**: NEVER (fixed price, no offers)

### 6. Transaction Flow
```
eBay Sale Detected
       ↓
Verify Serious Buyer (feedback + payment + requirements)
       ↓
Auto-message FB Seller: "I'll take it at your full asking price"
       ↓
Send Buyer Shipping Address to FB Seller
       ↓
FB Seller Ships Direct to eBay Buyer
       ↓
Pay FB Seller via Venmo/PayPal/Zelle (their full asking price)
       ↓
Margin = eBay Price - FB Price - eBay Fees (~13%)
```

## Technical Stack

- **Frontend**: React + TypeScript + Vite
- **Backend**: Node.js + Express
- **Database**: PostgreSQL (Koyeb)
- **Deployment**: Koyeb (free tier)
- **Scraping**: Puppeteer/Playwright + residential proxies
- **ML**: Python (pricing model) or TypeScript with TensorFlow.js
- **LLM**: Claude API for item matching/interpretation
- **eBay**: eBay Browse API (comps) + Sell API (listing)

## Key Entities

### Listing
```typescript
interface Listing {
  id: string;

  // Source (Facebook)
  fbListingId: string;
  fbUrl: string;
  fbPrice: number;           // What seller is asking
  fbTitle: string;
  fbDescription: string;
  fbPhotos: string[];
  fbLocation: string;
  fbSellerInfo: object;

  // Analysis
  mlPredictedValue: number;  // National market value
  mlConfidence: number;      // 0-1 confidence score
  arbitrageSpread: number;   // (mlValue - fbPrice) / fbPrice
  shippingEstimate: number;
  scamScore: number;         // 0-1, higher = more suspicious

  // eBay Comparables
  ebayComps: EbayComp[];     // Matched sold listings
  matchMethod: 'keyword' | 'image' | 'upc' | 'llm';

  // Destination (eBay)
  ebayListingId?: string;
  ebayUrl?: string;
  ebayPrice: number;         // = mlPredictedValue
  ebayListedAt?: Date;

  // Status
  status: 'scraped' | 'analyzed' | 'filtered_out' | 'listed' | 'sold' | 'stale';
  filterReason?: string;     // Why it was filtered out
}

interface EbayComp {
  itemId: string;
  title: string;
  soldPrice: number;
  soldDate: Date;
  condition: string;
  similarity: number;        // 0-1 match confidence
}
```

### Transaction
```typescript
interface Transaction {
  id: string;
  listingId: string;

  // Pricing
  fbPrice: number;           // What we pay seller
  ebayPrice: number;         // What buyer paid
  ebayFees: number;          // ~13%
  shippingCost: number;      // If we paid for label
  grossMargin: number;       // ebayPrice - fbPrice
  netMargin: number;         // grossMargin - ebayFees - shippingCost

  // Buyer (eBay)
  ebayOrderId: string;
  ebayBuyerId: string;
  buyerFeedback: number;
  shippingAddress: object;

  // Seller (FB)
  fbSellerId: string;
  sellerContacted: boolean;
  sellerResponse: 'pending' | 'accepted' | 'declined' | 'no_response';
  sellerPaymentMethod: 'venmo' | 'paypal' | 'zelle';
  sellerPaidAt?: Date;

  // Fulfillment
  status: 'pending' | 'seller_contacted' | 'confirmed' | 'shipped' | 'delivered' | 'refunded';
  trackingNumber?: string;
}
```

## Development Workflow

```bash
npm install          # Install dependencies
npm run dev          # Start dev server
npm run lint         # Run linter
npm test             # Run tests
npm run build        # Production build
```

## Environment Variables

```bash
# Database (Koyeb Postgres)
DATABASE_URL=postgresql://...

# eBay API
EBAY_CLIENT_ID=...
EBAY_CLIENT_SECRET=...
EBAY_REFRESH_TOKEN=...

# Claude API (for LLM matching)
ANTHROPIC_API_KEY=sk-ant-...

# Scraping
SCRAPER_PROXY_URL=...        # Residential proxy
SCRAPER_USER_AGENT=...

# Payments (for tracking, not processing)
# Actual payments via Venmo/PayPal/Zelle manually

# Application
NODE_ENV=development
PORT=3000
```

## Manager-Worker Architecture

This repo uses a manager-worker pattern with Claude Code:

- **Manager**: Grooms backlog, spawns workers, merges PRs
- **Workers**: Implement one GitHub issue each in isolated worktrees

See `.claude/manager/` for orchestration scripts.

## Commit Message Format

```
type(scope): description

Types: feat, fix, docs, refactor, test, chore
Scopes: scraper, ebay, ml, api, web, db
```

---

**Remember**:
- We find LOCAL deals and sell them NATIONALLY
- We ALWAYS pay sellers their full asking price
- We NEVER negotiate our eBay price
- We only list items we're CONFIDENT about
- Speed and automation are key to scale
