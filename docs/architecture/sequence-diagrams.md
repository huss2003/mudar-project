# Sequence Diagrams

This document contains Mermaid sequence diagrams illustrating key workflows in the Jasfo platform: the weekly pipeline execution, the scoring workflow, the decision-maker lookup process, and the email outreach sequence.

## Weekly Pipeline Execution

```mermaid
sequenceDiagram
    actor Broker
    participant Scheduler as Make.com Scheduler
    participant Pipeline as Make.com Pipeline
    participant Firecrawl as Firecrawl API
    participant Apify as Apify API
    participant Supabase as Supabase DB
    participant DeepSeek as DeepSeek V4 Flash
    participant MiMo as MiMo V2.5
    participant Claude as Claude Sonnet 4
    participant Telegram as Telegram Bot
    
    Note over Broker,Telegram: Weekly Pipeline - Monday 00:00 IST
    
    Scheduler->>Pipeline: Trigger pipeline (00:00 IST)
    Pipeline->>Supabase: Read company list (10,000)
    Pipeline->>Firecrawl: Bulk scrape company websites
    Firecrawl-->>Pipeline: Return raw HTML/JSON
    
    alt Firecrawl fails (429 or empty)
        Pipeline->>Apify: Fallback scraping
        Apify-->>Pipeline: Return scraped data
    end
    
    Pipeline->>Supabase: Store raw scraped data
    
    Pipeline->>DeepSeek: Normalize company data (Layer 2)
    DeepSeek-->>Pipeline: Return normalized records
    Pipeline->>Supabase: Store normalized records
    
    Pipeline->>MiMo: Verify claims (Layer 3)
    MiMo-->>Pipeline: Return verified claims
    Pipeline->>Supabase: Store verified claims
    
    Pipeline->>DeepSeek: Extract features (Layer 4)
    DeepSeek-->>Pipeline: Return feature vectors
    Pipeline->>Supabase: Store feature vectors
    
    par Specialist Agents (Layers 5-9)
        DeepSeek-->>Pipeline: Growth analysis
        DeepSeek-->>Pipeline: Space analysis
        MiMo-->>Pipeline: Financial analysis
        DeepSeek-->>Pipeline: Industry analysis
        DeepSeek-->>Pipeline: Decision-maker analysis
    end
    
    Pipeline->>MiMo: Reach consensus (Layer 10)
    MiMo-->>Pipeline: Return unified scores
    Pipeline->>Supabase: Store scores in Lead Memory
    
    Pipeline->>DeepSeek: Detect changes (Layer 12)
    DeepSeek-->>Pipeline: Return change deltas
    
    Note over Pipeline: Cost Gate (Layer 13)
    Pipeline->>Supabase: Check score > threshold
    
    alt Score >= 70
        Pipeline->>DeepSeek: Enrich contacts (Layer 14)
        DeepSeek-->>Pipeline: Return decision-makers
        
        Pipeline->>MiMo: Generate strategy (Layer 15)
        MiMo-->>Pipeline: Return outreach strategy
        
        Pipeline->>Claude: Final evaluation (Layer 16)
        Claude-->>Pipeline: Return final score & evidence
        
        Pipeline->>Supabase: Store evidence package
        
        Pipeline->>Telegram: Send weekly summary
        Telegram-->>Broker: "20 leads ready - View CSV"
        
        Pipeline->>Supabase: Generate CSV/Excel export
    else Score < 70
        Pipeline->>Supabase: Queue for next run
    end
    
    Note over Broker: Monday Morning
    Broker->>Supabase: Review lead evidence packages
    Broker->>Broker: Make outreach calls (10-15)
```

## Scoring Workflow

```mermaid
sequenceDiagram
    participant Agents as Specialist Agents
    participant Consensus as Consensus Engine
    participant Memory as Lead Memory
    participant Judge as Claude Sonnet 4 Judge
    participant Broker as Broker
    
    Note over Agents,Broker: This diagram traces one company through scoring
    
    par Parallel Analysis
        Agents->>Agents: Growth Agent analyzes hiring, funding, expansion
        Agents->>Agents: Space Agent analyzes lease events, capacity
        Agents->>Agents: Financial Agent analyzes revenue, investment
        Agents->>Agents: Industry Agent analyzes sector trends
        Agents->>Agents: Decision Agent analyzes org structure
    end
    
    Agents->>Consensus: Submit independent scores (0-100 each)
    
    Consensus->>Consensus: Compare agent scores
    
    alt Agents Agree (variance < 15%)
        Consensus->>Consensus: Weighted average score
    else Agents Disagree (variance >= 15%)
        Consensus->>Agents: Request additional evidence
        Agents->>Consensus: Provide supplementary analysis
        Consensus->>Consensus: Re-weight and re-compute
    end
    
    Consensus->>Memory: Store consensus score (0-100)
    Memory->>Memory: Compare with historical scores
    
    alt Significant Change Detected (delta > 20%)
        Memory->>Judge: High priority flag added
    else Minor or No Change
        Memory->>Judge: Standard priority
    end
    
    Judge->>Judge: Evaluate complete evidence package
    Judge->>Judge: Apply scoring rubric
    Judge->>Judge: Check all claims have source URLs
    
    Note over Judge: Scoring Rubric<br/>Growth: 40%<br/>Space Need: 30%<br/>Financial: 15%<br/>Industry: 10%<br/>Decision Access: 5%
    
    alt Score >= 70 and All Claims Verified
        Judge->>Broker: Include in weekly delivery
    else Score < 70 or Unverified Claims
        Judge->>Report: Downgrade or discard
    end
    
    Broker->>Broker: Contact lead and confirm signals
    Broker->>Memory: Record feedback (accurate/inaccurate)
    Memory->>Memory: Calibrate weights for next cycle
```

## Decision-Maker Lookup

```mermaid
sequenceDiagram
    participant Pipeline as Pipeline
    participant DeepSeek as DeepSeek V4 Flash
    participant Firecrawl as Firecrawl
    participant Web as Company Website
    participant LinkedIn as LinkedIn (via Apify)
    participant Supabase as Supabase
    
    Note over Pipeline,Supabase: Contact Enrichment Layer
    
    Pipeline->>Supabase: Read company profile
    Pipeline->>Firecrawl: Scrape "Team" or "Leadership" page
    
    alt Team page found
        Firecrawl->>Web: Extract leadership section
        Web-->>Firecrawl: Return team page HTML
        Firecrawl-->>Pipeline: Return leadership data
    else Team page not found
        Firecrawl-->>Pipeline: Return empty result
    end
    
    alt Primary scrape incomplete or insufficient
        Pipeline->>LinkedIn: Look up company leadership
        LinkedIn-->>Pipeline: Return executive profiles
    end
    
    Pipeline->>DeepSeek: Extract decision-maker contacts
    
    Note over DeepSeek: Target roles:<br/>- CEO / Managing Director<br/>- CFO / Finance Head<br/>- Head of Operations<br/>- Facilities Manager<br/>- HR Head
    
    DeepSeek-->>Pipeline: Return structured contact list
    
    alt Contacts found
        Pipeline->>Supabase: Store contacts with source URLs
    else No contacts found
        Pipeline->>Supabase: Mark as "no contacts"
        Pipeline->>Supabase: Flag for manual broker lookup
    end
    
    Pipeline->>Supabase: Request email addresses
    Supabase->>Supabase: Check existing contact store
    
    alt Email on file
        Supabase-->>Pipeline: Return stored email
    else Email not on file
        Pipeline->>DeepSeek: Infer email pattern from public data
        DeepSeek-->>Pipeline: Return best-guess email
        Pipeline->>Supabase: Store inferred email (unverified)
    end
    
    Pipeline-->>Pipeline: Continue to Commercial Strategy layer
```

## Email Outreach Sequence

```mermaid
sequenceDiagram
    actor Broker
    participant Lead as Lead Evidence Package
    participant Inbox as Broker's Email
    participant Prospect as Decision-Maker
    
    Note over Broker,Prospect: Broker executes outreach (NOT automated)
    
    Broker->>Lead: Review evidence package (Monday)
    Lead-->>Broker: Show signals, contacts, strategy
    
    Broker->>Broker: Select top 10-15 leads for outreach
    Broker->>Broker: Personalize email per lead
    
    Note over Broker: Email structure:<br/>1. Reference specific company signal<br/>2. Introduce yourself as CRE specialist<br/>3. Offer market insight relevant to signal<br/>4. Suggest brief call to discuss
    
    Broker->>Inbox: Send personalized email
    Inbox->>Prospect: Deliver email
    Note over Prospect: Email received (same day or next day)
    
    alt Positive Response
        Prospect->>Inbox: "Yes, interested in discussing"
        Inbox-->>Broker: Forward reply
        Broker->>Broker: Schedule introductory call
        Broker->>Broker: Prepare market data for meeting
    else Neutral Response
        Prospect->>Inbox: "Not now, but keep in touch"
        Inbox-->>Broker: Forward reply
        Broker->>Lead: Schedule follow-up in 60 days
    else No Response
        Note over Broker: Wait 3-4 days
        Broker->>Inbox: Send brief follow-up (adds value, not pressure)
        
        alt Still No Response
            Broker->>Lead: Move to nurture sequence
            Note over Broker: Re-engage in 30 days with new market data
        end
    end
    
    Note over Broker,Prospect: If meeting booked
    Broker->>Broker: Prepare property recommendations
    Broker->>Prospect: Conduct introductory call
    Broker->>Broker: Log feedback to Lead Memory
    Broker->>Memory: Record which signals were confirmed
    Memory->>Memory: Calibrate scoring for future runs
```
