# AI Stylist Cost Analysis & Optimization Guide

## 💰 Current Cost Breakdown (Per Generation)

### Primary Costs

| Component | Cost per Call | Notes |
|-----------|--------------|-------|
| **Imagen 3 (1024x1024)** | **$0.03 - $0.039** | Primary expense |
| **Imagen 3 (2048x2048)** | **$0.134** | Higher resolution |
| **Imagen 3 (4096x4096)** | **$0.24** | Maximum quality |
| **Data Transfer (In)** | ~$0.0001 | User image upload (~500KB) |
| **Data Transfer (Out)** | ~$0.0003 | Generated image download (~1.5MB) |
| **API Request Overhead** | Negligible | Included in base price |

**Total Cost per Generation (1024x1024)**: **~$0.031 per outfit**

---

## 📊 Cost Distribution

```
Imagen API:        97% ($0.03)
Network Transfer:   1% ($0.0004)
API Overhead:       2% (negligible)
```

**Key Insight**: The Imagen API is >97% of the cost. Optimizing image generation is critical.

---

## 🎯 Cost Reduction Strategies

### 1. **Switch to Imagen 4 Standard** ✅ RECOMMENDED
- **Cost**: $0.04 per image (vs $0.03-0.039 for Imagen 3)
- **Why**: Imagen 4 offers better quality at similar price
- **Imagen 4 Ultra**: $0.06 (premium quality, 2x cost)

**Recommendation**: Use Imagen 4 Standard for production

---

### 2. **Aggressive Caching** ⭐ HIGH IMPACT
Save generated images locally to avoid re-generating the same outfit.

**Implementation**:
```swift
// Cache key: hash of selected item IDs + gender
func cacheKey(items: [ClothingItem], gender: Gender) -> String {
    let ids = items.map { $0.id.uuidString }.sorted().joined()
    return "\(ids)-\(gender)".sha256
}
```

**Savings**: 
- 80-90% reduction if users repeatedly style the same items
- Cost per outfit drops from $0.03 → $0.003 (cached retrieval)

**Storage Cost**:
- 1,000 cached images × 1.5MB = 1.5GB
- Local storage: FREE
- Cloud storage (if needed): ~$0.02/month for 1.5GB

---

### 3. **Reduce Output Resolution** ⭐ HIGH IMPACT
Our current config uses default resolution. We can optimize:

| Resolution | Cost | Quality | Recommendation |
|------------|------|---------|----------------|
| 1024x1024 | $0.03 | Good | ✅ **Use for mobile** |
| 2048x2048 | $0.134 | Excellent | ❌ Overkill for phones |
| 4096x4096 | $0.24 | Ultra | ❌ Never needed |

**Action**: Explicitly set `aspectRatio: "3:4"` and limit to 1024px width in our API call.

**Savings**: Avoid accidental high-res generations (4x-8x cost increase)

---

### 4. **Batch Processing** (Future)
If users generate multiple looks, batch requests.

**Savings**: Minimal (Imagen charges per image anyway)
**Benefit**: Better UX, not cost savings

---

### 5. **Alternative AI Models** (Longer Term)

| Model | Cost per Image | Quality vs Imagen | Notes |
|-------|----------------|-------------------|-------|
| **DALL-E 3** | $0.040-0.080 | Comparable | Similar pricing |
| **Midjourney** | ~$0.06 | Artistic, not realistic | Not API-friendly |
| **Stable Diffusion** | $0.002-0.01 | Lower quality | Self-hosted or Replicate.com |
| **RunwayML Gen-2** | ~$0.05 | Good, but video-focused | Not ideal |

**Imagen 3/4 Verdict**: Best quality/price ratio for realistic model photos.

---

## 🔥 Immediate Action Plan

### Phase 1: Quick Wins (This Week)
1. ✅ **Set explicit resolution to 1024x1024** in `StylistService.swift`
2. ✅ **Implement local caching** (hash-based)
3. ✅ **Add cache hit rate tracking**

**Expected Savings**: $0.03 → $0.006 average (with 80% cache hit)

---

### Phase 2: Monitoring (Next Week)
1. Track cache hit rate
2. Monitor average cost per user per month
3. Set spending alerts in GCP Console

---

### Phase 3: Advanced Optimizations (Future)
1. **User limits**: Free tier = 10 generations/month, then paywall
2. **Progressive quality**: Start with 512px preview (cheap), upgrade to 1024px on user request
3. **Server-side proxy**: Route all API calls through your backend to:
   - Implement unified caching
   - Track per-user usage
   - Add rate limiting

---

## 💡 Revised Cost Estimate (With Optimizations)

### Before Optimization
- **Cost per generation**: $0.031
- **100 users × 20 generations/month**: $62/month

### After Optimization (Caching + Resolution Limit)
- **Cache hit rate**: 80%
- **Effective cost**: $0.031 × 20% = $0.0062 per generation
- **100 users × 20 generations/month**: $12.40/month

**Savings**: **80% reduction** ($50/month)

---

## 🚨 Cost Control Recommendations

1. **Set GCP Spending Limits**
   - Go to: GCP Console → Billing → Budgets & Alerts
   - Set: $50/month alert, $100/month hard cap

2. **Implement User Quotas**
   ```swift
   // Limit free users to 10 generations/month
   let freeUserLimit = 10
   let premiumUserLimit = 100
   ```

3. **Cache Everything**
   - Save generated images to app's Documents directory
   - Key: `\(itemIDs)-\(gender).jpg`

4. **Monitor Usage**
   - Track generations per user
   - Alert if single user exceeds 50/month (potential abuse)

---

## 📈 Paywall Strategy

### Free Tier
- 10 AI-generated looks per month
- Cached results don't count against limit

### Premium Tier ($4.99/month)
- Unlimited AI generations
- Priority processing
- Save outfit history

**Break-even**: 150 generations/month per premium user (profitable with caching)

---

## ✅ Updated StylistService Config

Update `callImagenAPI` to explicitly control resolution:

```swift
let requestBody: [String: Any] = [
    "instances": [["prompt": prompt]],
    "parameters": [
        "sampleCount": 1,
        "aspectRatio": "3:4",
        "outputImageWidth": 1024,  // ⬅️ ADD THIS
        "negativePrompt": "blurry, distorted, low quality",
        "personGeneration": "allow_adult"
    ]
]
```

This guarantees we never accidentally generate expensive high-res images.
