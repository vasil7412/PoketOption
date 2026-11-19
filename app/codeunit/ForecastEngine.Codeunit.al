/// <summary>
/// Single entry point to run a forecast method on a context. Results are cached in the context per method and position.
/// </summary>
codeunit 50118 "SMA Forecast Engine"
{
    /// <summary>
    /// Forecasts the next Steps candles after the current position of the context.
    /// Points and Sigmas may be longer than Steps and are shared with the cache: read them, do not modify them.
    /// </summary>
    procedure GetForecast(var ForecastContext: Codeunit "SMA Forecast Context"; ForecastMethod: Enum "SMA Forecast Method"; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal])
    var
        ForecastImpl: Interface "SMA IForecast Method";
        NewPoints: List of [Decimal];
        NewSigmas: List of [Decimal];
    begin
        if ForecastContext.TryGetCached(ForecastMethod.AsInteger(), Steps, Points, Sigmas) then
            exit;
        ForecastImpl := ForecastMethod;
        ForecastImpl.Forecast(ForecastContext, Steps, NewPoints, NewSigmas);
        Points := NewPoints;
        Sigmas := NewSigmas;
        if (NewPoints.Count() >= Steps) and (NewSigmas.Count() >= Steps) then
            ForecastContext.SetCached(ForecastMethod.AsInteger(), NewPoints, NewSigmas);
    end;
}
