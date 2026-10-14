enum 50102 "SMA Forecast Method" implements "SMA IForecast Method"
{
    Extensible = true;

    value(0; "Linear Regression")
    {
        Caption = 'Linear Regression';
        Implementation = "SMA IForecast Method" = "SMA Linear Regression Fcst";
    }
    value(1; "Holt Damped Trend")
    {
        Caption = 'Holt Damped Trend';
        Implementation = "SMA IForecast Method" = "SMA Holt Damped Fcst";
    }
    value(2; Ensemble)
    {
        Caption = 'Ensemble';
        Implementation = "SMA IForecast Method" = "SMA Ensemble Fcst";
    }
}
