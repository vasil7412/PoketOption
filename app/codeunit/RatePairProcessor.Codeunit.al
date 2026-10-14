/// <summary>
/// Full processing cycle of one pair: download new candles, store a fresh forecast, evaluate matured forecasts.
/// Run it with Codeunit.Run to isolate errors of one pair.
/// </summary>
codeunit 50113 "SMA Rate Pair Processor"
{
    TableNo = "SMA Currency Pair";

    trigger OnRun()
    var
        TempRateForecast: Record "SMA Rate Forecast" temporary;
        RateSyncMgt: Codeunit "SMA Rate Sync Mgt";
        ForecastMgt: Codeunit "SMA Forecast Mgt";
    begin
        RateSyncMgt.SyncPair(Rec);
        if ForecastMgt.BuildForecast(Rec, Rec."Forecast Method", Rec."Forecast Horizon (Min)", TempRateForecast) then
            ForecastMgt.SaveForecast(TempRateForecast);
        ForecastMgt.EvaluateForecasts(Rec);
    end;
}
