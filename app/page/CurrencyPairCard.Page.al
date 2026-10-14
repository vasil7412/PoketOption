page 50102 "SMA Currency Pair Card"
{
    Caption = 'Currency Pair';
    PageType = Card;
    SourceTable = "SMA Currency Pair";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Code"; Rec.Code) { }
                field(Description; Rec.Description) { }
                field("Base Currency"; Rec."Base Currency") { }
                field("Quote Currency"; Rec."Quote Currency") { }
                field("Price Decimals"; Rec."Price Decimals") { }
                field(Active; Rec.Active) { }
            }
            group(DataSource)
            {
                Caption = 'Data Source';

                field(Provider; Rec.Provider) { }
                field("Provider Symbol"; Rec."Provider Symbol") { }
                field(Timeframe; Rec.Timeframe) { }
            }
            group(Forecast)
            {
                Caption = 'Forecast';

                field("Forecast Method"; Rec."Forecast Method") { }
                field("Forecast Horizon (Min)"; Rec."Forecast Horizon (Min)") { }
                field(HitRate; Rec.GetHitRateText())
                {
                    Caption = 'Direction Hit Rate';
                    ToolTip = 'Specifies how often the stored forecasts at the horizon predicted the price direction correctly.';
                }
            }
            group(Status)
            {
                Caption = 'Status';

                field("Last Candle Time"; Rec."Last Candle Time") { }
                field("Last Sync At"; Rec."Last Sync At") { }
                field("No. of Candles"; Rec."No. of Candles") { }
                field("Last Sync Error"; Rec."Last Sync Error")
                {
                    MultiLine = true;
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
                ToolTip = 'Opens the live chart with the forecast.';
                Image = AnalysisView;
                RunObject = page "SMA Rate Analyzer";
                RunPageLink = Code = field(Code);
            }
            action(SyncNow)
            {
                Caption = 'Download Rates';
                ToolTip = 'Downloads new candles and updates the forecast.';
                Image = Refresh;

                trigger OnAction()
                var
                    RateSyncMgt: Codeunit "SMA Rate Sync Mgt";
                begin
                    CurrPage.SaveRecord();
                    Commit();
                    ClearLastError();
                    if not Codeunit.Run(Codeunit::"SMA Rate Pair Processor", Rec) then begin
                        RateSyncMgt.SetSyncError(Rec, GetLastErrorText());
                        Commit();
                        Error(GetLastErrorText());
                    end;
                    CurrPage.Update(false);
                end;
            }
            action(Backtest)
            {
                Caption = 'Run Backtest';
                ToolTip = 'Replays all forecast methods over the stored history and shows how often each one predicted the direction correctly.';
                Image = TestReport;

                trigger OnAction()
                var
                    BacktestResult: Record "SMA Backtest Result";
                    ForecastBacktest: Codeunit "SMA Forecast Backtest";
                begin
                    CurrPage.SaveRecord();
                    ForecastBacktest.RunBacktest(Rec, Rec."Forecast Horizon (Min)");
                    Commit();
                    BacktestResult.SetRange("Pair Code", Rec.Code);
                    Page.Run(Page::"SMA Backtest Results", BacktestResult);
                end;
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
            actionref(Backtest_Promoted; Backtest) { }
        }
    }
}
