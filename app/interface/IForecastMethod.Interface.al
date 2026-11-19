interface "SMA IForecast Method"
{
    /// <summary>
    /// Forecasts the next Steps close prices after the current position of the context.
    /// Points receives the predicted prices, Sigmas the standard deviation of the forecast error for every step.
    /// Leave Points empty if there is not enough data. Only candles up to the current position may be used.
    /// Do not call other methods directly: use codeunit "SMA Forecast Engine", which caches results.
    /// </summary>
    procedure Forecast(var ForecastContext: Codeunit "SMA Forecast Context"; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal]);
}
