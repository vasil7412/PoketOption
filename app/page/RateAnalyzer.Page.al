page 50105 "SMA Rate Analyzer"
{
    Caption = 'Rate Analyzer';
    PageType = Card;
    SourceTable = "SMA Currency Pair";
    UsageCategory = Tasks;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;
    DataCaptionExpression = Rec.Code + ' ' + Rec.Description;

    layout
    {
        area(Content)
        {
            group(Summary)
            {
                Caption = 'Forecast';

                group(Settings)
                {
                    ShowCaption = false;

                    field("Code"; Rec.Code)
                    {
                        Editable = false;
                    }
                    field(HorizonMin; HorizonMin)
                    {
                        Caption = 'Horizon (Min)';
                        ToolTip = 'Specifies how many minutes ahead the forecast on the chart is built. Changing it does not affect stored forecasts, which use the horizon of the pair.';
                        MinValue = 1;
                        MaxValue = 60;

                        trigger OnValidate()
                        begin
                            RefreshChart(false);
                        end;
                    }
                    field(ForecastMethod; ForecastMethod)
                    {
                        Caption = 'Method';
                        ToolTip = 'Specifies the forecast method shown on the chart. Changing it does not affect stored forecasts, which use the method of the pair.';

                        trigger OnValidate()
                        begin
                            RefreshChart(false);
                        end;
                    }
                }
                group(Values)
                {
                    ShowCaption = false;

                    field(LastPriceText; LastPriceText)
                    {
                        Caption = 'Last Price';
                        ToolTip = 'Specifies the close price of the latest candle.';
                        Editable = false;
                    }
                    field(ForecastText; ForecastText)
                    {
                        Caption = 'Forecast';
                        ToolTip = 'Specifies the predicted price at the end of the horizon and the expected change.';
                        Editable = false;
                        StyleExpr = ForecastStyle;
                    }
                    field(BandText; BandText)
                    {
                        Caption = 'Confidence Band';
                        ToolTip = 'Specifies the range the price is expected to stay in at the end of the horizon.';
                        Editable = false;
                    }
                    field(HitRateText; HitRateText)
                    {
                        Caption = 'Direction Hit Rate';
                        ToolTip = 'Specifies how often the stored forecasts of this pair predicted the price direction correctly. Around 50% means no predictive power.';
                        Editable = false;
                    }
                    field(StatusText; StatusText)
                    {
                        Caption = 'Status';
                        ToolTip = 'Specifies the result of the last refresh.';
                        Editable = false;
                        StyleExpr = StatusStyle;
                    }
                }
            }
            group(ChartGroup)
            {
                Caption = 'Chart';

                usercontrol(RateChart; "SMA Rate Chart")
                {
                    ApplicationArea = All;

                    trigger OnControlReady()
                    begin
                        ChartReady := true;
                        LoadPair();
                    end;

                    trigger OnRefreshRequested()
                    begin
                        RefreshChart(true);
                    end;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RefreshNow)
            {
                Caption = 'Refresh';
                ToolTip = 'Downloads new candles and rebuilds the forecast now.';
                Image = Refresh;

                trigger OnAction()
                begin
                    RefreshChart(true);
                end;
            }
            action(PauseAutoRefresh)
            {
                Caption = 'Pause Auto Refresh';
                ToolTip = 'Stops the automatic refresh of the chart.';
                Image = Pause;
                Visible = AutoRefresh;

                trigger OnAction()
                begin
                    SetAutoRefresh(false);
                end;
            }
            action(ResumeAutoRefresh)
            {
                Caption = 'Resume Auto Refresh';
                ToolTip = 'Starts the automatic refresh of the chart.';
                Image = Start;
                Visible = not AutoRefresh;

                trigger OnAction()
                begin
                    SetAutoRefresh(true);
                end;
            }
            action(Backtest)
            {
                Caption = 'Run Backtest';
                ToolTip = 'Replays all forecast methods over the stored history with the selected horizon and shows how often each one predicted the direction correctly.';
                Image = TestReport;

                trigger OnAction()
                var
                    BacktestResult: Record "SMA Backtest Result";
                    ForecastBacktest: Codeunit "SMA Forecast Backtest";
                begin
                    ForecastBacktest.RunBacktest(Rec, HorizonMin);
                    Commit();
                    BacktestResult.SetRange("Pair Code", Rec.Code);
                    Page.Run(Page::"SMA Backtest Results", BacktestResult);
                end;
            }
        }
        area(Navigation)
        {
            action(PairCard)
            {
                Caption = 'Currency Pair';
                ToolTip = 'Opens the settings of the currency pair.';
                Image = Setup;
                RunObject = page "SMA Currency Pair Card";
                RunPageLink = Code = field(Code);
            }
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
        }
        area(Promoted)
        {
            actionref(RefreshNow_Promoted; RefreshNow) { }
            actionref(PauseAutoRefresh_Promoted; PauseAutoRefresh) { }
            actionref(ResumeAutoRefresh_Promoted; ResumeAutoRefresh) { }
            actionref(Backtest_Promoted; Backtest) { }
            actionref(Forecasts_Promoted; Forecasts) { }
        }
    }

    trigger OnOpenPage()
    begin
        RateAnalyzerSetup.GetRecordOnce();
        AutoRefresh := true;
    end;

    trigger OnAfterGetCurrRecord()
    begin
        // CurrPage.Update in RefreshChart raises this trigger again; reload only when the user moved to another pair
        if ChartReady and (Rec.Code <> LoadedPairCode) then
            LoadPair();
    end;

    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        ForecastMgt: Codeunit "SMA Forecast Mgt";
        RateChartMgt: Codeunit "SMA Rate Chart Mgt";
        RateSyncMgt: Codeunit "SMA Rate Sync Mgt";
        ForecastMethod: Enum "SMA Forecast Method";
        LoadedPairCode: Code[20];
        HorizonMin: Integer;
        ChartReady: Boolean;
        AutoRefresh: Boolean;
        LastPriceText: Text;
        ForecastText: Text;
        ForecastStyle: Text;
        BandText: Text;
        HitRateText: Text;
        StatusText: Text;
        StatusStyle: Text;
        UpdatedTxt: Label 'Updated at %1', Comment = '%1 = time';
        PausedTxt: Label 'Auto refresh paused';
        NotEnoughDataTxt: Label 'Not enough candles for a forecast yet';
        ForecastTxt: Label '%1 at %2 (%3%4%)', Comment = '%1 = price, %2 = target time, %3 = sign, %4 = change percent';
        BandTxt: Label '%1 - %2', Locked = true;
        PriceFormatTok: Label '<Precision,%1:%1><Standard Format,0>', Locked = true;

    local procedure LoadPair()
    begin
        LoadedPairCode := Rec.Code;
        HorizonMin := Rec."Forecast Horizon (Min)";
        if HorizonMin <= 0 then
            HorizonMin := RateAnalyzerSetup."Default Horizon (Min)";
        ForecastMethod := Rec."Forecast Method";
        CurrPage.RateChart.Init(RateChartMgt.BuildOptions(Rec));
        RefreshChart(true);
        CurrPage.RateChart.SetAutoRefresh(AutoRefresh, RateAnalyzerSetup."Refresh Interval (Sec)");
    end;

    local procedure RefreshChart(FetchRates: Boolean)
    var
        TempRateForecast: Record "SMA Rate Forecast" temporary;
    begin
        if not ChartReady then
            exit;

        if FetchRates and RateAnalyzerSetup."Live Fetch on Refresh" then begin
            Commit();
            ClearLastError();
            if Codeunit.Run(Codeunit::"SMA Rate Pair Processor", Rec) then
                SetStatus(StrSubstNo(UpdatedTxt, Time()), false)
            else begin
                SetStatus(GetLastErrorText(), true);
                RateSyncMgt.SetSyncError(Rec, StatusText);
                Commit();
            end;
        end else
            if FetchRates then
                SetStatus(StrSubstNo(UpdatedTxt, Time()), false);
        if not Rec.Find() then
            exit;

        if not ForecastMgt.BuildForecast(Rec, ForecastMethod, HorizonMin, TempRateForecast) then
            SetStatus(NotEnoughDataTxt, false);
        CurrPage.RateChart.SetData(RateChartMgt.BuildChartData(Rec, ForecastMethod, HorizonMin, TempRateForecast));
        UpdateSummary(TempRateForecast);
        CurrPage.Update(false);
    end;

    local procedure UpdateSummary(var TempRateForecast: Record "SMA Rate Forecast" temporary)
    var
        ChangePct: Decimal;
        SignText: Text;
    begin
        LastPriceText := '';
        ForecastText := '';
        BandText := '';
        ForecastStyle := 'Standard';
        HitRateText := Rec.GetHitRateText();

        TempRateForecast.Reset();
        TempRateForecast.SetRange("Horizon Step", true);
        if not TempRateForecast.FindFirst() then
            exit;

        LastPriceText := FormatPrice(TempRateForecast."Base Close");
        if TempRateForecast."Base Close" <> 0 then
            ChangePct := Round((TempRateForecast."Predicted Close" - TempRateForecast."Base Close") / TempRateForecast."Base Close" * 100, 0.001);
        if ChangePct >= 0 then
            SignText := '+';
        ForecastText := StrSubstNo(ForecastTxt, FormatPrice(TempRateForecast."Predicted Close"), Format(DT2Time(TempRateForecast."Target Time")), SignText, ChangePct);
        BandText := StrSubstNo(BandTxt, FormatPrice(TempRateForecast."Lower Bound"), FormatPrice(TempRateForecast."Upper Bound"));
        case true of
            TempRateForecast."Predicted Close" > TempRateForecast."Base Close":
                ForecastStyle := 'Favorable';
            TempRateForecast."Predicted Close" < TempRateForecast."Base Close":
                ForecastStyle := 'Unfavorable';
        end;
        TempRateForecast.Reset();
    end;

    local procedure SetAutoRefresh(Enabled: Boolean)
    begin
        AutoRefresh := Enabled;
        if ChartReady then
            CurrPage.RateChart.SetAutoRefresh(AutoRefresh, RateAnalyzerSetup."Refresh Interval (Sec)");
        if AutoRefresh then
            RefreshChart(true)
        else
            SetStatus(PausedTxt, false);
    end;

    local procedure SetStatus(NewStatus: Text; IsError: Boolean)
    begin
        StatusText := NewStatus;
        StatusStyle := 'Standard';
        if IsError then
            StatusStyle := 'Unfavorable';
    end;

    local procedure FormatPrice(Value: Decimal): Text
    begin
        exit(Format(Round(Value, Power(10, -Rec."Price Decimals")), 0, StrSubstNo(PriceFormatTok, Rec."Price Decimals")));
    end;
}
