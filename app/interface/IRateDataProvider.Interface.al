interface "SMA IRate Data Provider"
{
    /// <summary>
    /// Returns the instrument symbol used by the provider for the given currencies (e.g. EUR/USD, EUR_USD, BTCUSDT).
    /// </summary>
    procedure GetDefaultSymbol(BaseCurrency: Code[10]; QuoteCurrency: Code[10]): Text[30];

    /// <summary>
    /// Maximum number of candles the provider returns in one request.
    /// </summary>
    procedure GetMaxCandlesPerRequest(): Integer;

    /// <summary>
    /// Loads candles of the pair timeframe starting at FromTime (UTC), at most MaxCount candles, into TempRateCandle.
    /// </summary>
    procedure FetchCandles(CurrencyPair: Record "SMA Currency Pair"; FromTime: DateTime; MaxCount: Integer; var TempRateCandle: Record "SMA Rate Candle" temporary);
}
