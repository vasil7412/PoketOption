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
    value(3; Autoregression)
    {
        Caption = 'Autoregression (AR)';
        Implementation = "SMA IForecast Method" = "SMA Autoregression Fcst";
    }
    value(4; "Mean Reversion")
    {
        Caption = 'Mean Reversion';
        Implementation = "SMA IForecast Method" = "SMA Mean Reversion Fcst";
    }
    value(5; RSI)
    {
        Caption = 'RSI';
        Implementation = "SMA IForecast Method" = "SMA RSI Fcst";
    }
    value(6; Stochastic)
    {
        Caption = 'Stochastic';
        Implementation = "SMA IForecast Method" = "SMA Stochastic Fcst";
    }
    value(7; "Last Candle")
    {
        Caption = 'Last Candle (Baseline)';
        Implementation = "SMA IForecast Method" = "SMA Last Candle Fcst";
    }
    value(8; "Weighted Ensemble")
    {
        Caption = 'Weighted Ensemble';
        Implementation = "SMA IForecast Method" = "SMA Weighted Ensemble Fcst";
    }
    value(9; "Adaptive (Live)")
    {
        Caption = 'Adaptive (Live)';
        Implementation = "SMA IForecast Method" = "SMA Adaptive Fcst";
    }
    value(10; "Logistic Regression")
    {
        Caption = 'Logistic Regression (Direction)';
        Implementation = "SMA IForecast Method" = "SMA Logistic Regression Fcst";
    }
}
