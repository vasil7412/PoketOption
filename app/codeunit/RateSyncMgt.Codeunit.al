codeunit 50100 "SMA Rate Sync Mgt"
{
    Permissions =
        tabledata "SMA Currency Pair" = rm,
        tabledata "SMA Rate Candle" = rimd;

    var
        RateHelper: Codeunit "SMA Rate Helper";

    /// <summary>
    /// Downloads new candles of the pair from its provider. On the first run loads the initial history.
    /// The last (still forming) candle is downloaded again on every run, so it gets updated.
    /// </summary>
    /// <returns>Number of inserted or updated candles.</returns>
    procedure SyncPair(var CurrencyPair: Record "SMA Currency Pair"): Integer
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        TempRateCandle: Record "SMA Rate Candle" temporary;
        RateDataProvider: Interface "SMA IRate Data Provider";
        TimeframeDuration: Duration;
        HistoryDuration: Duration;
        HistoryMs: BigInteger;
        NowTime: DateTime;
        FromTime: DateTime;
        NextFromTime: DateTime;
        LastTime: DateTime;
        MaxCount: Integer;
        Iterations: Integer;
        ProcessedCount: Integer;
    begin
        RateAnalyzerSetup.GetRecordOnce();
        CurrencyPair.TestField("Provider Symbol");
        RateDataProvider := CurrencyPair.Provider;
        MaxCount := RateDataProvider.GetMaxCandlesPerRequest();
        TimeframeDuration := RateHelper.GetTimeframeDuration(CurrencyPair.Timeframe);
        NowTime := CurrentDateTime();

        LastTime := GetLastCandleTime(CurrencyPair);
        if LastTime = 0DT then begin
            HistoryMs := RateAnalyzerSetup."Initial History Days";
            HistoryMs := HistoryMs * 24 * 60 * 60 * 1000;
            HistoryDuration := HistoryMs;
            FromTime := NowTime - HistoryDuration;
        end else
            FromTime := LastTime - TimeframeDuration;

        repeat
            Iterations += 1;
            TempRateCandle.Reset();
            TempRateCandle.DeleteAll();
            RateDataProvider.FetchCandles(CurrencyPair, FromTime, MaxCount, TempRateCandle);

            if TempRateCandle.FindSet() then begin
                repeat
                    UpsertCandle(TempRateCandle, NowTime, TimeframeDuration);
                    ProcessedCount += 1;
                until TempRateCandle.Next() = 0;
                TempRateCandle.FindLast();
                if TempRateCandle."Open Time" > LastTime then
                    LastTime := TempRateCandle."Open Time";
                NextFromTime := TempRateCandle."Open Time" + TimeframeDuration;
            end else
                // nothing in this window (market closed) - jump over it
                NextFromTime := FromTime + TimeframeDuration * MaxCount;

            if NextFromTime <= FromTime then
                break;
            FromTime := NextFromTime;
        until (FromTime > NowTime) or (Iterations >= MaxRequestsPerSync());

        CurrencyPair."Last Candle Time" := LastTime;
        CurrencyPair."Last Sync At" := CurrentDateTime();
        CurrencyPair."Last Sync Error" := '';
        CurrencyPair.Modify();
        exit(ProcessedCount);
    end;

    procedure GetLastCandleTime(CurrencyPair: Record "SMA Currency Pair"): DateTime
    var
        RateCandle: Record "SMA Rate Candle";
    begin
        RateCandle.SetRange("Pair Code", CurrencyPair.Code);
        RateCandle.SetRange(Timeframe, CurrencyPair.Timeframe);
        RateCandle.SetLoadFields("Open Time");
        if RateCandle.FindLast() then
            exit(RateCandle."Open Time");
        exit(0DT);
    end;

    procedure SetSyncError(CurrencyPair: Record "SMA Currency Pair"; ErrorText: Text)
    var
        CurrencyPairToUpdate: Record "SMA Currency Pair";
    begin
        if not CurrencyPairToUpdate.Get(CurrencyPair.Code) then
            exit;
        CurrencyPairToUpdate."Last Sync At" := CurrentDateTime();
        CurrencyPairToUpdate."Last Sync Error" := CopyStr(ErrorText, 1, MaxStrLen(CurrencyPairToUpdate."Last Sync Error"));
        CurrencyPairToUpdate.Modify();
    end;

    /// <summary>
    /// Deletes candles and forecasts older than configured in the setup.
    /// </summary>
    procedure PurgeOldData()
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        RateCandle: Record "SMA Rate Candle";
        RateForecast: Record "SMA Rate Forecast";
    begin
        RateAnalyzerSetup.GetRecordOnce();
        if RateAnalyzerSetup."Keep History Days" > 0 then begin
            RateCandle.SetFilter("Open Time", '<%1', DaysAgo(RateAnalyzerSetup."Keep History Days"));
            RateCandle.DeleteAll();
        end;
        if RateAnalyzerSetup."Keep Forecasts Days" > 0 then begin
            RateForecast.SetFilter("Base Time", '<%1', DaysAgo(RateAnalyzerSetup."Keep Forecasts Days"));
            RateForecast.DeleteAll();
        end;
    end;

    local procedure UpsertCandle(TempRateCandle: Record "SMA Rate Candle" temporary; NowTime: DateTime; TimeframeDuration: Duration)
    var
        RateCandle: Record "SMA Rate Candle";
        IsComplete: Boolean;
    begin
        IsComplete := TempRateCandle."Open Time" + TimeframeDuration <= NowTime;
        if RateCandle.Get(TempRateCandle."Pair Code", TempRateCandle.Timeframe, TempRateCandle."Open Time") then begin
            if (RateCandle.Close = TempRateCandle.Close) and (RateCandle.High = TempRateCandle.High) and
               (RateCandle.Low = TempRateCandle.Low) and (RateCandle.Complete = IsComplete)
            then
                exit;
            RateCandle.TransferFields(TempRateCandle, false);
            RateCandle.Complete := IsComplete;
            RateCandle.Modify();
            exit;
        end;
        RateCandle := TempRateCandle;
        RateCandle.Complete := IsComplete;
        RateCandle.Insert();
    end;

    local procedure DaysAgo(Days: Integer): DateTime
    var
        Ms: BigInteger;
        Offset: Duration;
    begin
        Ms := Days;
        Ms := Ms * 24 * 60 * 60 * 1000;
        Offset := Ms;
        exit(CurrentDateTime() - Offset);
    end;

    local procedure MaxRequestsPerSync(): Integer
    begin
        exit(200);
    end;
}
