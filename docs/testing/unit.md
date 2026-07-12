# Unit Testing

Unit tests form the foundation of the Jasfo Lead Intelligence Platform's testing strategy. They validate individual functions, database operations, and validation logic in isolation — without network calls, external APIs, or database dependencies where possible. The unit test suite covers three primary areas: PostgreSQL stored functions and scoring logic, JSON schema validation for API contracts, and scoring algorithm correctness.

## Test Organization

Unit tests are organized by component under `tests/unit/`:

```
tests/unit/
  database/
    test_scoring_functions.py   — SQL scoring function tests
    test_company_queries.py     — Company CRUD operation tests
    test_pipeline_state.py      — Pipeline state machine tests
  validation/
    test_json_schema.py         — API request/response validation
    test_input_sanitization.py  — Input cleaning and normalization
  scoring/
    test_algorithm.py           — Scoring algorithm correctness
    test_weight_calculation.py  — Weight and score computation
    test_normalization.py       — Score normalization to 0–100 scale
  utils/
    test_export.py              — CSV/JSON export formatting
    test_notifications.py       — Notification message formatting
```

## Postgres Function Tests

Database functions are tested using `pytest` with a transactional PostgreSQL connection. Each test creates a database transaction, executes the function, and rolls back — leaving no side effects:

```python
# tests/unit/database/test_scoring_functions.py
import pytest
from utils.db import get_test_connection

class TestScoreCompany:
    """Tests for the score_company() Postgres function."""

    def test_score_returns_valid_range(self, db_connection):
        """score_company() must return a value between 0 and 100."""
        test_company_id = 42
        result = db_connection.execute(
            "SELECT * FROM score_company($1, $2)",
            [test_company_id, '{"revenue": 5000000, "employees": 50}']
        ).fetchone()
        
        assert 0 <= result.score <= 100, f"Score {result.score} out of range"

    def test_score_requires_valid_json(self, db_connection):
        """score_company() must reject invalid JSON input."""
        with pytest.raises(Exception, match="invalid input"):
            db_connection.execute(
                "SELECT * FROM score_company($1, $2)",
                [42, "not valid json"]
            )

    def test_score_empty_input_returns_default(self, db_connection):
        """score_company() with empty signals must return default score."""
        result = db_connection.execute(
            "SELECT * FROM score_company($1, $2)",
            [42, '{}']
        ).fetchone()
        
        assert result.score == 0
        assert result.confidence == "low"
```

Key Postgres functions under test:

| Function | Purpose | Critical Test Cases |
|---|---|---|
| `score_company()` | Computes overall lead score | Boundaries, empty input, edge weights |
| `calculate_pillar()` | Scores one of 8 pillars | Each pillar has specific metric requirements |
| `normalize_score()` | Normalizes to 0–100 scale | Min, max, midpoint, out-of-range inputs |
| `get_company_signals()` | Aggregates company signals | Missing data, partial results, timeouts |
| `update_pipeline_state()` | Advances pipeline state | Valid transitions, invalid transitions |

## JSON Schema Validation

All API request and response payloads are validated against JSON Schema definitions. Schema tests ensure contract compliance without running the full API stack:

```python
# tests/unit/validation/test_json_schema.py
import json
from jsonschema import validate, ValidationError

class TestScoreResponseSchema:
    """Tests for the score response JSON schema."""

    def test_standard_score_response(self):
        """A standard score response must validate against the schema."""
        payload = {
            "company_id": 42,
            "overall_score": 78.5,
            "pillars": {
                "management": 82,
                "growth": 75,
                "culture": 80
            },
            "confidence": "high",
            "scored_at": "2026-07-12T10:00:00Z"
        }
        validate(payload, SCORE_RESPONSE_SCHEMA)

    def test_score_response_with_warnings(self):
        """Score response with partial data must include confidence metadata."""
        payload = {
            "company_id": 42,
            "overall_score": 45.0,
            "pillars": {
                "management": None,
                "growth": 45,
                "culture": None
            },
            "confidence": "low",
            "scored_at": "2026-07-12T10:00:00Z",
            "warnings": [
                "Management pillar: insufficient data"
            ]
        }
        validate(payload, SCORE_RESPONSE_SCHEMA)

    def test_missing_required_field(self):
        """Response missing required fields must fail validation."""
        payload = {"company_id": 42}  # missing score
        with pytest.raises(ValidationError):
            validate(payload, SCORE_RESPONSE_SCHEMA)
```

## Scoring Algorithm Tests

The scoring algorithm tests validate the mathematical correctness of score computation, weight application, and normalization — independent of the data source or pipeline:

```python
# tests/unit/scoring/test_algorithm.py

class TestScoreAggregation:
    """Tests for score aggregation and normalization."""

    def test_weighted_average(self):
        """Weighted average must compute correctly with standard weights."""
        pillar_scores = {
            "management": 80,
            "growth": 70,
            "culture": 90,
        }
        weights = {
            "management": 0.4,
            "growth": 0.35,
            "culture": 0.25,
        }
        result = compute_weighted_average(pillar_scores, weights)
        # (80 * 0.4) + (70 * 0.35) + (90 * 0.25) = 32 + 24.5 + 22.5 = 79
        assert result == pytest.approx(79.0, rel=1e-2)

    def test_weights_must_sum_to_one(self):
        """Weight configuration must be validated."""
        invalid_weights = {"management": 1.0, "growth": 0.5}
        with pytest.raises(ValueError, match="Weights must sum to 1.0"):
            compute_weighted_average({"management": 50, "growth": 50}, invalid_weights)

    def test_normalization_clamps_extremes(self):
        """Normalization must clamp values to 0–100 range."""
        assert normalize(150) == 100
        assert normalize(-10) == 0
        assert normalize(75) == 75
```

## Running Unit Tests

```bash
# Run all unit tests
pytest tests/unit/ -v

# Run with coverage
pytest tests/unit/ --cov=src/ --cov-report=term-missing

# Run specific test file
pytest tests/unit/scoring/test_algorithm.py -v

# Run by marker
pytest tests/unit/ -m "not slow" -v

# Run with parallel execution (4 workers)
pytest tests/unit/ -n 4 -v
```

## Coverage Targets

| Module | Minimum Coverage | Target Coverage |
|---|---|---|
| Scoring functions | 90% | 95% |
| JSON validation | 95% | 100% |
| Database layer | 80% | 90% |
| Utility functions | 85% | 95% |
| **Overall** | **85%** | **92%** |

Coverage below the minimum blocks merging to `main`. The target coverage is aspirational and tracked in weekly reports.
