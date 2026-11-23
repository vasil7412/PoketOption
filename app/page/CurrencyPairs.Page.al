page 50101 "SMA Currency Pairs"
{
    Caption = 'Rate Analyzer Currency Pairs';
    PageType = List;
    SourceTable = "SMA Currency Pair";
    UsageCategory = Lists;
    ApplicationArea = All;
    CardPageId = "SMA Currency Pair Card";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Pairs)
            {
                field("Code"; Rec.Code) { }
                field(Description; Rec.Description) { }
                field(Provider; Rec.Provider) { }
                field("Provider Symbol"; Rec."Provider Symbol") { }
                field(Timeframe; Rec.Timeframe) { }
                field("Skip Weekend Data"; Rec."Skip Weekend Data") { }
                field(Active; Rec.Active) { }
                field("Forecast Method"; Rec."Forecast Method") { }
                field("Forecast Horizon (Min)"; Rec."Forecast Horizon (Min)") { }
                field("Last Candle Time"; Rec."Last Candle Time") { }
                field("No. of Candles"; Rec."No. of Candles") { }
                field(HitRate; Rec.GetHitRateText())
                {
                    Caption = 'Direction Hit Rate';
                    ToolTip = 'Specifies how often the stored forecasts at the horizon predicted the price direction correctly.';
                }
                field("Last Sync Error"; Rec."Last Sync Error")
                {
                    Style = Unfavorable;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenAnalyzer)
            {
                Caption = 'Analyzer';
                ToolTip = 'Opens the live chart with the forecast for the selected pair.';
                Image = AnalysisView;
                RunObject = page "SMA Rate Analyzer";
                RunPageLink = Code = field(Code);
            }
            action(SyncNow)
            {
                Caption = 'Download Rates';
                ToolTip = 'Downloads new candles and updates the forecast for the selected pairs.';
                Image = Refresh;

                trigger OnAction()
                var
                    CurrencyPair: Record "SMA Currency Pair";
                begin
                    CurrPage.SetSelectionFilter(CurrencyPair);
                    ProcessPairs(CurrencyPair);
                end;
            }
            action(FillParameters)
            {
                Caption = 'Fill Parameters';
                ToolTip = 'Fills empty fields of the Rate Analyzer Setup with their defaults, sets Skip Weekend Data on all pairs by their provider (on for forex, off for Binance crypto) and deletes the stored synthetic weekend candles and the forecasts built on them for the pairs that skip weekends.';
                Image = Apply;

                trigger OnAction()
                var
                    DataMaintenance: Codeunit "SMA Data Maintenance";
                    SetupFieldsFilled: Integer;
                    PairsUpdated: Integer;
                    CandlesDeleted: Integer;
                    ForecastsDeleted: Integer;
                    ConfirmQst: Label 'This fills the empty (zero or blank) fields of the Rate Analyzer Setup with their defaults, turns Skip Weekend Data on for forex pairs and off for Binance pairs, and deletes the stored weekend candles (Friday 21:00 to Sunday 22:00 UTC) and the forecasts built on them for the forex pairs.\\Do you want to continue?';
                    DoneMsg: Label 'Setup fields filled with defaults: %1\Pairs updated: %2\Weekend candles deleted: %3\Weekend forecasts deleted: %4', Comment = '%1 = setup fields, %2 = pairs, %3 = candles, %4 = forecasts';
                begin
                    if not Confirm(ConfirmQst, false) then
                        exit;
                    DataMaintenance.FillParameters(SetupFieldsFilled, PairsUpdated, CandlesDeleted, ForecastsDeleted);
                    Message(DoneMsg, SetupFieldsFilled, PairsUpdated, CandlesDeleted, ForecastsDeleted);
                    CurrPage.Update(false);
                end;
            }
            action(Setup)
            {
                Caption = 'Setup';
                ToolTip = 'Opens the Rate Analyzer setup.';
                Image = Setup;
                RunObject = page "SMA Rate Analyzer Setup";
            }
        }
        area(Navigation)
        {
            action(Candles)
            {
                Caption = 'Candles';
                ToolTip = 'Shows the stored candles of the pair.';
                Image = Ledger;
                RunObject = page "SMA Rate Candles";
                RunPageLink = "Pair Code" = field(Code), Timeframe = field(Timeframe);
            }
            action(Forecasts)
            {
                Caption = 'Forecasts';
                ToolTip = 'Shows the stored forecasts of the pair and how they matched the actual price.';
                Image = Forecast;
                RunObject = page "SMA Rate Forecasts";
                RunPageLink = "Pair Code" = field(Code), Timeframe = field(Timeframe);
            }
            action(BacktestResults)
            {
                Caption = 'Backtest Results';
                ToolTip = 'Shows the backtest results of the pair.';
                Image = TestReport;
                RunObject = page "SMA Backtest Results";
                RunPageLink = "Pair Code" = field(Code);
            }
        }
        area(Promoted)
        {
            actionref(OpenAnalyzer_Promoted; OpenAnalyzer) { }
            actionref(SyncNow_Promoted; SyncNow) { }
            actionref(FillParameters_Promoted; FillParameters) { }
            actionref(Candles_Promoted; Candles) { }
            actionref(Forecasts_Promoted; Forecasts) { }
        }
    }

    local procedure ProcessPairs(var CurrencyPair: Record "SMA Currency Pair")
    var
        RateSyncMgt: Codeunit "SMA Rate Sync Mgt";
        FailedCount: Integer;
        DoneMsg: Label 'Rates have been downloaded. Failed pairs: %1. See the Last Sync Error column.', Comment = '%1 = number of failed pairs';
    begin
        if CurrencyPair.FindSet() then
            repeat
                Commit();
                ClearLastError();
                if not Codeunit.Run(Codeunit::"SMA Rate Pair Processor", CurrencyPair) then begin
                    RateSyncMgt.SetSyncError(CurrencyPair, GetLastErrorText());
                    FailedCount += 1;
                end;
            until CurrencyPair.Next() = 0;
        Message(DoneMsg, FailedCount);
        CurrPage.Update(false);
    end;
}
