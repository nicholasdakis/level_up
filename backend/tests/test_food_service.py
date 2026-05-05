import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import MagicMock
from backend.services.food_service import FoodService


def make_service(token_manager=None, rate_limit_repo=None):
    return FoodService(
        token_manager=token_manager or MagicMock(),
        rate_limit_repo=rate_limit_repo or MagicMock(),
        client_id="test_id",
        client_secret="test_secret",
    )


# get_next_reset_time tests -----------------

# No refill time on record means the rate limit has never been set — return None
def test_get_next_reset_time_no_refill():
    rate_limit_repo = MagicMock()
    rate_limit_repo.get_last_refill_time.return_value = None
    service = make_service(rate_limit_repo=rate_limit_repo)

    assert service.get_next_reset_time() is None

# Reset time must be exactly 24 hours after the last refill
def test_get_next_reset_time_is_one_day_after_refill():
    last_refill = datetime(2026, 5, 1, 12, 0, 0, tzinfo=timezone.utc)
    rate_limit_repo = MagicMock()
    rate_limit_repo.get_last_refill_time.return_value = last_refill
    service = make_service(rate_limit_repo=rate_limit_repo)

    result = service.get_next_reset_time()

    assert result == datetime(2026, 5, 2, 12, 0, 0, tzinfo=timezone.utc)

# call_fatsecret tests -----------------

# If the access token fetch fails, a refund must be issued and RuntimeError raised
def test_call_fatsecret_no_access_token_refunds(mocker):
    token_manager = MagicMock()
    service = make_service(token_manager=token_manager)
    mocker.patch.object(service, "get_access_token", return_value=None)

    with pytest.raises(RuntimeError, match="Failed to get access token"):
        service.call_fatsecret("chicken", timeout=5)

    token_manager.refund.assert_called_once()

# A non-200 response from FatSecret must trigger a refund and raise RuntimeError
def test_call_fatsecret_api_error_refunds(mocker):
    token_manager = MagicMock()
    service = make_service(token_manager=token_manager)
    mocker.patch.object(service, "get_access_token", return_value="valid_token")

    mock_response = MagicMock()
    mock_response.status_code = 500
    mocker.patch("backend.services.food_service.requests.post", return_value=mock_response)

    with pytest.raises(RuntimeError, match="FatSecret API error"):
        service.call_fatsecret("chicken", timeout=5)

    token_manager.refund.assert_called_once()

# A network error must trigger a refund and raise RuntimeError
def test_call_fatsecret_network_error_refunds(mocker):
    import requests as req
    token_manager = MagicMock()
    service = make_service(token_manager=token_manager)
    mocker.patch.object(service, "get_access_token", return_value="valid_token")
    mocker.patch("backend.services.food_service.requests.post", side_effect=req.RequestException("timeout"))

    with pytest.raises(RuntimeError):
        service.call_fatsecret("chicken", timeout=5)

    token_manager.refund.assert_called_once()

# A successful 200 response must return the response object without touching the token manager
def test_call_fatsecret_success_no_refund(mocker):
    token_manager = MagicMock()
    service = make_service(token_manager=token_manager)
    mocker.patch.object(service, "get_access_token", return_value="valid_token")

    mock_response = MagicMock()
    mock_response.status_code = 200
    mocker.patch("backend.services.food_service.requests.post", return_value=mock_response)

    result = service.call_fatsecret("chicken", timeout=5)

    assert result == mock_response
    token_manager.refund.assert_not_called()
