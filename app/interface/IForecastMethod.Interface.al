interface "SMA IForecast Method"
{
    /// <summary>
    /// Forecasts the next Steps values of the Series (oldest value first).
    /// Points receives the predicted values, Sigmas the standard deviation of the forecast error for every step.
    /// </summary>
    procedure Forecast(Series: List of [Decimal]; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal]);
}
