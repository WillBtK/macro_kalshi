import requests

def get_kalshi_series_tickers(series_ticker="KXCPICOREYOY"):
    """
    Fetch all market tickers for a given Kalshi series.
    
    Args:
        series_ticker (str): The series ticker (default: KXCPICOREYOY).
    
    Returns:
        list[str]: List of tickers for all markets in the series.
    """
    base_url = "https://api.elections.kalshi.com/trade-api/v2/markets"
    tickers = []
    cursor = None

    while True:
        params = {
            "series_ticker": series_ticker,
            "limit": 100
        }
        if cursor:
            params["cursor"] = cursor

        resp = requests.get(base_url, params=params)
        resp.raise_for_status()
        data = resp.json()

        tickers.extend([m["ticker"] for m in data.get("markets", [])])
        cursor = data.get("cursor")

        if not cursor:
            break

    return tickers

# Example usage
all_tickers = get_kalshi_series_tickers()
print(all_tickers)
