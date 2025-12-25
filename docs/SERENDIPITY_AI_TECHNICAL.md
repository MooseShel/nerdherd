# Serendipity Engine: AI/ML Technical Implementation

## Overview
The Serendipity Engine uses three distinct ML/AI systems working together:
1. **Struggle Detection** (NLP)
2. **Compatibility Matching** (Graph Neural Network + Collaborative Filtering)
3. **Temporal Pattern Recognition** (Time-Series Analysis)

---

## 1. Struggle Detection (NLP)

### Purpose
Automatically detect when a user is struggling with a topic from their chat messages, status updates, or manual input.

### Technology Stack
- **Model**: Gemini Flash 2.0 or GPT-4o-mini (via API)
- **Why**: Fast, cost-effective, good at semantic understanding
- **Fallback**: Local keyword matching for offline/low-cost mode

### Implementation

#### Edge Function: `detect-struggle`
```typescript
// supabase/functions/detect-struggle/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from '@supabase/supabase-js'

serve(async (req) => {
  const { message, userId } = await req.json()
  
  // Call Gemini API
  const prompt = `Analyze this student message and extract:
1. Subject (e.g., "Calculus", "Python Programming")
2. Specific topic (e.g., "Integration", "Recursion")
3. Struggle level (1-5, where 5 is very stuck)

Message: "${message}"

Respond in JSON: {"subject": "...", "topic": "...", "level": 1-5}`

  const response = await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': Deno.env.get('GEMINI_API_KEY')
    },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }]
    })
  })
  
  const data = await response.json()
  const analysis = JSON.parse(data.candidates[0].content.parts[0].text)
  
  // Store in database
  const supabase = createClient(...)
  await supabase.from('struggle_signals').insert({
    user_id: userId,
    subject: analysis.subject,
    topic: analysis.topic,
    confidence_level: analysis.level,
    location: userLocation, // from client
    expires_at: new Date(Date.now() + 2 * 60 * 60 * 1000) // 2 hours
  })
  
  return new Response(JSON.stringify({ success: true }))
})
```

#### Trigger Points
1. **Chat Messages**: Webhook on message insert containing keywords ("stuck", "confused", "help")
2. **Manual Input**: User explicitly sets status via UI
3. **Search Patterns**: Multiple searches for same topic within 10 minutes

### Cost Optimization
- **Batch Processing**: Queue messages and process every 30 seconds instead of real-time
- **Caching**: Store common subject/topic extractions
- **Estimated Cost**: ~$0.0001 per message = $1 per 10,000 messages

---

## 2. Compatibility Matching (The "Study Constellation")

### Purpose
Find 2-3 students with complementary skill gaps who would benefit from forming a study group.

### Technology Stack
- **Primary**: Graph Neural Network (GNN) using PyTorch Geometric
- **Alternative**: Collaborative Filtering (simpler, faster to implement)
- **Hosting**: Supabase Edge Function calling external ML service (Modal, Replicate, or self-hosted)

### Data Model

#### Skill Matrix
Each user represented as a vector:
```python
user_vector = [
  calculus_strength,      # 0-1 (from reviews, grades, tutoring history)
  programming_strength,   # 0-1
  communication_skill,    # 0-1 (from peer reviews)
  availability_score,     # 0-1 (how often online)
  # ... for each subject/skill
]
```

### Algorithm: Collaborative Filtering (MVP)

#### Step 1: Build User-Skill Matrix
```python
import numpy as np
from scipy.sparse import csr_matrix

# Example: 1000 users x 50 skills
user_skill_matrix = csr_matrix((1000, 50))

# Populate from database
# user_skill_matrix[user_id, skill_id] = competence_score (0-1)
```

#### Step 2: Find Complementary Users
```python
def find_complementary_group(target_user_id, user_skill_matrix):
    """
    Find 2-3 users where:
    - User A is strong where User B is weak (and vice versa)
    - All users have overlapping courses/subjects
    """
    target_vector = user_skill_matrix[target_user_id]
    
    # Find users with inverse skill profile
    # High complementarity = low cosine similarity in strengths
    complementarity_scores = []
    
    for other_user_id in range(len(user_skill_matrix)):
        if other_user_id == target_user_id:
            continue
            
        other_vector = user_skill_matrix[other_user_id]
        
        # Calculate complementarity
        # Where target is weak (< 0.4), other should be strong (> 0.6)
        target_weak = target_vector < 0.4
        other_strong = other_vector > 0.6
        complement_score = np.sum(target_weak & other_strong)
        
        complementarity_scores.append((other_user_id, complement_score))
    
    # Return top 2-3 matches
    complementarity_scores.sort(key=lambda x: x[1], reverse=True)
    return [uid for uid, score in complementarity_scores[:3]]
```

#### Step 3: Edge Function Implementation
```typescript
// supabase/functions/compute-compatibility/index.ts
serve(async (req) => {
  const { userId } = await req.json()
  
  // Call Python ML service (hosted on Modal/Replicate)
  const response = await fetch('https://your-ml-service.modal.run/find-matches', {
    method: 'POST',
    body: JSON.stringify({ user_id: userId })
  })
  
  const matches = await response.json() // [user_id_1, user_id_2, user_id_3]
  
  // Store in compatibility_scores table
  const supabase = createClient(...)
  for (const matchId of matches) {
    await supabase.from('compatibility_scores').upsert({
      user_a: userId,
      user_b: matchId,
      score: 0.85, // from ML model
      factors: { skill_complement: 0.9, temporal_overlap: 0.8 },
      last_updated: new Date()
    })
  }
  
  return new Response(JSON.stringify({ matches }))
})
```

### Advanced: Graph Neural Network (Future)

For more sophisticated matching, use GNN to model the entire campus social graph:

```python
import torch
from torch_geometric.nn import GCNConv

class StudentMatchingGNN(torch.nn.Module):
    def __init__(self, num_features):
        super().__init__()
        self.conv1 = GCNConv(num_features, 64)
        self.conv2 = GCNConv(64, 32)
        
    def forward(self, x, edge_index):
        # x: node features (user skill vectors)
        # edge_index: existing connections
        x = self.conv1(x, edge_index).relu()
        x = self.conv2(x, edge_index)
        return x

# Training: Predict successful study group formations
# Input: Historical data of groups that stayed together > 1 month
```

### Frequency
- **Batch Job**: Run nightly for all active users (10k users = ~5 min processing)
- **On-Demand**: When user explicitly requests recommendations

---

## 3. Temporal Pattern Recognition

### Purpose
Identify each user's "golden hours" (when they're most productive) and match with students who have overlapping patterns.

### Technology Stack
- **Simple**: SQL aggregation + percentile analysis
- **Advanced**: LSTM (Long Short-Term Memory) for pattern prediction

### Implementation (Simple Version)

#### Step 1: Collect Activity Data
```sql
-- Track every app interaction
INSERT INTO activity_logs (user_id, event_type, timestamp)
VALUES (user_id, 'study_session_start', NOW());
```

#### Step 2: Analyze Patterns (SQL)
```sql
-- Find user's most active hours
WITH hourly_activity AS (
  SELECT 
    user_id,
    EXTRACT(HOUR FROM timestamp) as hour,
    COUNT(*) as activity_count
  FROM activity_logs
  WHERE event_type IN ('study_session_start', 'app_open')
    AND timestamp > NOW() - INTERVAL '30 days'
  GROUP BY user_id, hour
)
SELECT 
  user_id,
  hour,
  activity_count,
  RANK() OVER (PARTITION BY user_id ORDER BY activity_count DESC) as rank
FROM hourly_activity
WHERE rank <= 3; -- Top 3 productive hours
```

#### Step 3: Store in Profile
```typescript
// supabase/functions/analyze-temporal-patterns/index.ts
serve(async (req) => {
  const supabase = createClient(...)
  
  // Get all users
  const { data: users } = await supabase.from('profiles').select('id')
  
  for (const user of users) {
    // Run SQL query above
    const { data: topHours } = await supabase.rpc('get_top_productive_hours', {
      p_user_id: user.id
    })
    
    // Store as JSONB
    await supabase.from('profiles').update({
      productivity_hours: topHours // [18, 19, 20] = 6-8 PM
    }).eq('id', user.id)
  }
  
  return new Response(JSON.stringify({ success: true }))
})
```

#### Step 4: Match Users
```sql
-- Find users with overlapping productive hours
SELECT 
  p1.id as user_a,
  p2.id as user_b,
  (
    SELECT COUNT(*)
    FROM jsonb_array_elements_text(p1.productivity_hours) h1
    WHERE h1 = ANY(SELECT jsonb_array_elements_text(p2.productivity_hours))
  ) as overlap_count
FROM profiles p1
CROSS JOIN profiles p2
WHERE p1.id < p2.id
  AND overlap_count >= 2; -- At least 2 overlapping hours
```

---

## Infrastructure & Hosting

### Option 1: Fully Managed (Recommended for MVP)
- **NLP**: Gemini API (Google) or OpenAI API
- **ML Compute**: Modal.com or Replicate.com (serverless Python)
- **Database**: Supabase (PostgreSQL with pgvector extension)
- **Cost**: ~$50-200/month for 10k active users

### Option 2: Self-Hosted (For Scale)
- **ML Service**: FastAPI + PyTorch on AWS Lambda or Google Cloud Run
- **Vector DB**: Supabase pgvector or Pinecone
- **Cost**: ~$500-1000/month for 100k users

---

## Data Flow Diagram

```
User Activity (Chat, Status, Location)
    ↓
[Edge Function: detect-struggle]
    ↓
Gemini API (NLP)
    ↓
struggle_signals table
    ↓
[Cron: proximity-matcher] ← Reads location + signals
    ↓
[Edge Function: compute-compatibility] ← Calls ML service
    ↓
Python ML Service (Collaborative Filtering)
    ↓
compatibility_scores table
    ↓
[UI: Proximity Alert / Constellation Recommendation]
```

---

## Performance Targets

| Metric | Target | Strategy |
|--------|--------|----------|
| NLP Latency | < 500ms | Use Gemini Flash (fastest model) |
| Compatibility Compute | < 5 min for 10k users | Batch processing, caching |
| Proximity Alert Delay | < 1 min | Cron every 5 min + push notifications |
| Battery Impact | < 5% per hour | Efficient geofencing, background limits |

---

## Privacy & Ethics

### Data Minimization
- Only process struggle signals from users who opt-in
- Anonymize data sent to external ML APIs
- Delete struggle signals after 2 hours

### Transparency
- Show users exactly what data is used for matching
- Allow opt-out at any time
- Explain match reasoning ("You both study best at 9 PM")

---

## Testing Strategy

### Unit Tests
```python
def test_complementarity_matching():
    # User A: Strong in Math (0.9), Weak in Programming (0.2)
    # User B: Weak in Math (0.3), Strong in Programming (0.8)
    user_a = np.array([0.9, 0.2])
    user_b = np.array([0.3, 0.8])
    
    score = calculate_complementarity(user_a, user_b)
    assert score > 0.7  # High complementarity
```

### Integration Tests
1. Simulate 100 users with known skill profiles
2. Run compatibility algorithm
3. Verify top matches are indeed complementary

### A/B Testing
- **Control**: Random study group suggestions
- **Treatment**: ML-powered constellation matching
- **Metric**: % of groups that meet > 3 times
