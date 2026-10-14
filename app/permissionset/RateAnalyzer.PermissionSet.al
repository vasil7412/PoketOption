permissionset 50100 "SMA RATE ANALYZER"
{
    Caption = 'SMART Rate Analyzer';
    Assignable = true;

    Permissions =
        tabledata "SMA Rate Analyzer Setup" = RIMD,
        tabledata "SMA Currency Pair" = RIMD,
        tabledata "SMA Rate Candle" = RIMD,
        tabledata "SMA Rate Forecast" = RIMD,
        tabledata "SMA Backtest Result" = RIMD,
        table "SMA Rate Analyzer Setup" = X,
        table "SMA Currency Pair" = X,
        table "SMA Rate Candle" = X,
        table "SMA Rate Forecast" = X,
        table "SMA Backtest Result" = X,
        codeunit "SMA Rate Sync Mgt" = X,
        codeunit "SMA Twelve Data Provider" = X,
        codeunit "SMA OANDA Provider" = X,
        codeunit "SMA Binance Provider" = X,
        codeunit "SMA Forecast Mgt" = X,
        codeunit "SMA Linear Regression Fcst" = X,
        codeunit "SMA Holt Damped Fcst" = X,
        codeunit "SMA Ensemble Fcst" = X,
        codeunit "SMA Forecast Backtest" = X,
        codeunit "SMA Rate Sync Job" = X,
        codeunit "SMA Rate Helper" = X,
        codeunit "SMA Rate Chart Mgt" = X,
        codeunit "SMA Rate Pair Processor" = X,
        codeunit "SMA Forecast Math" = X,
        codeunit "SMA Rate Analyzer Mgt" = X,
        page "SMA Rate Analyzer Setup" = X,
        page "SMA Currency Pairs" = X,
        page "SMA Currency Pair Card" = X,
        page "SMA Rate Candles" = X,
        page "SMA Rate Forecasts" = X,
        page "SMA Rate Analyzer" = X,
        page "SMA Backtest Results" = X;
}
