table 50100 "SMA Rate Analyzer Setup"
{
    Caption = 'Rate Analyzer Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            AllowInCustomizations = Never;
        }
        field(10; "Refresh Interval (Sec)"; Integer)
        {
            Caption = 'Refresh Interval (Sec)';
            ToolTip = 'Specifies how often the analyzer page refreshes the chart and the forecast, in seconds. Keep in mind the request limits of your data provider.';
            InitValue = 15;
            MinValue = 5;
        }
        field(11; "Live Fetch on Refresh"; Boolean)
        {
            Caption = 'Live Fetch on Refresh';
            ToolTip = 'Specifies whether the analyzer page downloads new candles from the provider on every refresh. If disabled, the page only shows data loaded by the job queue.';
            InitValue = true;
        }
        field(20; "Default Forecast Method"; Enum "SMA Forecast Method")
        {
            Caption = 'Default Forecast Method';
            ToolTip = 'Specifies the forecast method assigned to new currency pairs.';
            InitValue = Ensemble;
        }
        field(21; "Default Horizon (Min)"; Integer)
        {
            Caption = 'Default Horizon (Min)';
            ToolTip = 'Specifies how many minutes ahead the forecast is built for new currency pairs.';
            InitValue = 5;
            MinValue = 1;
            MaxValue = 60;
        }
        field(22; "Lookback Candles"; Integer)
        {
            Caption = 'Lookback Candles';
            ToolTip = 'Specifies how many of the latest candles are used to build a forecast.';
            InitValue = 60;
            MinValue = 10;
            MaxValue = 1000;
        }
        field(23; "Band Width (Std. Dev.)"; Decimal)
        {
            Caption = 'Band Width (Std. Dev.)';
            ToolTip = 'Specifies the width of the forecast confidence band in standard deviations of the forecast error. 1.28 = 80%, 1.64 = 90%, 1.96 = 95%.';
            InitValue = 1.64;
            MinValue = 0;
            DecimalPlaces = 0 : 2;
        }
        field(24; "Holt Alpha"; Decimal)
        {
            Caption = 'Holt Alpha';
            ToolTip = 'Specifies the level smoothing factor of the Holt method (0..1). Higher values react faster to new prices.';
            InitValue = 0.5;
            MinValue = 0.01;
            MaxValue = 1;
            DecimalPlaces = 0 : 3;
        }
        field(25; "Holt Beta"; Decimal)
        {
            Caption = 'Holt Beta';
            ToolTip = 'Specifies the trend smoothing factor of the Holt method (0..1).';
            InitValue = 0.1;
            MinValue = 0.01;
            MaxValue = 1;
            DecimalPlaces = 0 : 3;
        }
        field(26; "Holt Damping"; Decimal)
        {
            Caption = 'Holt Damping';
            ToolTip = 'Specifies the trend damping factor of the Holt method (0..1). Lower values flatten the trend faster.';
            InitValue = 0.9;
            MinValue = 0.5;
            MaxValue = 1;
            DecimalPlaces = 0 : 3;
        }
        field(30; "Chart Candles"; Integer)
        {
            Caption = 'Chart Candles';
            ToolTip = 'Specifies how many of the latest candles are shown on the chart.';
            InitValue = 300;
            MinValue = 20;
            MaxValue = 5000;
        }
        field(31; "Initial History Days"; Integer)
        {
            Caption = 'Initial History Days';
            ToolTip = 'Specifies how many days of history are downloaded the first time a currency pair is synchronized.';
            InitValue = 3;
            MinValue = 1;
            MaxValue = 365;
        }
        field(32; "Keep History Days"; Integer)
        {
            Caption = 'Keep History Days';
            ToolTip = 'Specifies how many days of candles are kept. Older candles are deleted by the job queue. 0 means keep everything.';
            InitValue = 30;
            MinValue = 0;
        }
        field(33; "Keep Forecasts Days"; Integer)
        {
            Caption = 'Keep Forecasts Days';
            ToolTip = 'Specifies how many days of stored forecasts are kept. Older forecasts are deleted by the job queue. 0 means keep everything.';
            InitValue = 7;
            MinValue = 0;
        }
        field(34; "Backtest Candles"; Integer)
        {
            Caption = 'Backtest Candles';
            ToolTip = 'Specifies how many of the latest candles are used to backtest the forecast methods.';
            InitValue = 2000;
            MinValue = 100;
            MaxValue = 50000;
        }
        field(40; "OANDA Environment"; Enum "SMA OANDA Environment")
        {
            Caption = 'OANDA Environment';
            ToolTip = 'Specifies whether the OANDA practice (demo) or live API is used.';
        }
        field(41; "Binance Base URL"; Text[250])
        {
            Caption = 'Binance Base URL';
            ToolTip = 'Specifies the base URL of the Binance market data API. If api.binance.com returns status 451 (restricted location), use https://data-api.binance.vision or https://api.binance.us. If empty, https://data-api.binance.vision is used.';
            InitValue = 'https://data-api.binance.vision';
            ExtendedDatatype = URL;

            trigger OnValidate()
            begin
                "Binance Base URL" := CopyStr(DelChr("Binance Base URL", '>', '/ '), 1, MaxStrLen("Binance Base URL"));
            end;
        }
        field(50; "Payout %"; Decimal)
        {
            Caption = 'Payout %';
            ToolTip = 'Specifies the payout of a winning trade on your broker, in percent of the stake. It defines the breakeven hit rate of the trade signal: 80% payout needs at least 55.6% correct directions.';
            InitValue = 80;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 2;
        }
        field(51; "Signal Expirations (Min)"; Text[100])
        {
            Caption = 'Signal Expirations (Min)';
            ToolTip = 'Specifies the trade expirations in minutes the trade signal compares, separated by commas. Expirations that are not a whole number of candles of the pair timeframe are skipped.';
            InitValue = '1,2,3,5,10,15';
        }
        field(52; "Signal Backtest Candles"; Integer)
        {
            Caption = 'Signal Backtest Candles';
            ToolTip = 'Specifies how many of the latest complete candles are used to check the accuracy of every method and expiration for the trade signal. More candles give a more reliable estimate but take longer.';
            InitValue = 600;
            MinValue = 0;
            MaxValue = 5000;
        }
        field(53; "Signal Min. Samples"; Integer)
        {
            Caption = 'Signal Min. Samples';
            ToolTip = 'Specifies how many historical forecasts a method and expiration must have been checked on before a trade can be recommended.';
            InitValue = 50;
            MinValue = 0;
        }
        field(54; "Time-of-Day Filter"; Boolean)
        {
            Caption = 'Time-of-Day Filter';
            ToolTip = 'Specifies whether the trade signal judges every method only by historical trades opened at the same hour of the day as now. Markets behave differently in the Asian, London and New York sessions, but the filter needs several days of history (increase Signal Backtest Candles, for example to 5000).';
        }
        field(60; "AR Order"; Integer)
        {
            Caption = 'AR Order';
            ToolTip = 'Specifies how many previous candle changes the autoregression method uses to predict the next one (1..5).';
            InitValue = 2;
            MinValue = 1;
            MaxValue = 5;
        }
        field(61; "Mean Reversion Period"; Integer)
        {
            Caption = 'Mean Reversion Period';
            ToolTip = 'Specifies over how many candles the mean reversion method calculates the moving average and the deviation from it.';
            InitValue = 20;
            MinValue = 5;
            MaxValue = 500;
        }
        field(62; "Mean Reversion Z"; Decimal)
        {
            Caption = 'Mean Reversion Threshold (Std. Dev.)';
            ToolTip = 'Specifies how many standard deviations the price must move away from the moving average before the mean reversion method predicts a return to it. Below the threshold it gives no signal.';
            InitValue = 1;
            MinValue = 0;
            DecimalPlaces = 0 : 2;
        }
        field(63; "RSI Period"; Integer)
        {
            Caption = 'RSI Period';
            ToolTip = 'Specifies the period of the Relative Strength Index.';
            InitValue = 14;
            MinValue = 2;
            MaxValue = 200;
        }
        field(64; "RSI Oversold"; Decimal)
        {
            Caption = 'RSI Oversold';
            ToolTip = 'Specifies the RSI level at or below which the RSI method predicts a move up.';
            InitValue = 30;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 2;
        }
        field(65; "RSI Overbought"; Decimal)
        {
            Caption = 'RSI Overbought';
            ToolTip = 'Specifies the RSI level at or above which the RSI method predicts a move down.';
            InitValue = 70;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 2;
        }
        field(66; "Stochastic Period"; Integer)
        {
            Caption = 'Stochastic Period';
            ToolTip = 'Specifies over how many candles the stochastic oscillator looks for the highest high and the lowest low.';
            InitValue = 14;
            MinValue = 2;
            MaxValue = 200;
        }
        field(67; "Stochastic Smoothing"; Integer)
        {
            Caption = 'Stochastic Smoothing';
            ToolTip = 'Specifies over how many candles %K is averaged into the signal line %D.';
            InitValue = 3;
            MinValue = 1;
            MaxValue = 20;
        }
        field(68; "Stochastic Oversold"; Decimal)
        {
            Caption = 'Stochastic Oversold';
            ToolTip = 'Specifies the %K level at or below which the stochastic method predicts a move up, if %K turns above %D.';
            InitValue = 20;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 2;
        }
        field(69; "Stochastic Overbought"; Decimal)
        {
            Caption = 'Stochastic Overbought';
            ToolTip = 'Specifies the %K level at or above which the stochastic method predicts a move down, if %K turns below %D.';
            InitValue = 80;
            MinValue = 0;
            MaxValue = 100;
            DecimalPlaces = 0 : 2;
        }
        field(70; "Ensemble Weight Candles"; Integer)
        {
            Caption = 'Ensemble Weight Candles';
            ToolTip = 'Specifies on how many of the latest candles the weighted ensemble checks every method to weight it by its hit rate. Methods that guessed the direction in 50% or fewer cases get no weight.';
            InitValue = 100;
            MinValue = 10;
            MaxValue = 1000;
        }
        field(71; "Logistic Training Candles"; Integer)
        {
            Caption = 'Logistic Training Candles';
            ToolTip = 'Specifies on how many candles before the forecast the logistic regression method learns how the candle features relate to the later direction. More candles give a steadier model but adapt slower and take longer to calculate.';
            InitValue = 1000;
            MinValue = 50;
            MaxValue = 5000;
        }
        field(72; "Logistic Refit Interval"; Integer)
        {
            Caption = 'Logistic Refit Interval';
            ToolTip = 'Specifies after how many new candles the logistic regression method fits its model again. 1 refits on every candle (slow in backtests); larger values reuse the model for the next candles.';
            InitValue = 50;
            MinValue = 1;
            MaxValue = 500;
        }
        field(73; "Logistic Min. Probability %"; Decimal)
        {
            Caption = 'Logistic Min. Probability %';
            ToolTip = 'Specifies how probable the predicted direction must be before the logistic regression method gives a signal. Below it the forecast is flat (no trade). Keep it above the breakeven of the payout, for example 60% at 80% payout.';
            InitValue = 60;
            MinValue = 50;
            MaxValue = 99;
            DecimalPlaces = 0 : 2;
        }
        field(80; "Disable Live Tracking"; Boolean)
        {
            Caption = 'Disable Live Tracking';
            ToolTip = 'Specifies that the job queue stops recording and checking live forecasts of all methods. The method ranking and the Adaptive (Live) method then stop learning.';
        }
        field(81; "Tracking Interval (Min)"; Integer)
        {
            Caption = 'Tracking Interval (Min)';
            ToolTip = 'Specifies how often the job queue records the forecast of every method for every signal expiration, to check it later against the actual price.';
            InitValue = 3;
            MinValue = 1;
            MaxValue = 60;
        }
        field(82; "Learning Decay"; Decimal)
        {
            Caption = 'Learning Decay';
            ToolTip = 'Specifies how fast the method ranking forgets old results: on every new result all older ones are multiplied by this factor. 0.98 means the latest ~50 results of a method and expiration matter most; 1 means all results count equally.';
            InitValue = 0.98;
            MinValue = 0.5;
            MaxValue = 1;
            DecimalPlaces = 0 : 4;
        }
        field(83; "Min. Live Samples"; Integer)
        {
            Caption = 'Min. Live Samples';
            ToolTip = 'Specifies how many checked live forecasts a method needs for an expiration before it gets a weight in the Adaptive (Live) method.';
            InitValue = 20;
            MinValue = 1;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    var
        RecordHasBeenRead: Boolean;
        TwelveDataKeyTok: Label 'SMA-RATE-TWELVEDATA-KEY', Locked = true;
        OANDATokenTok: Label 'SMA-RATE-OANDA-TOKEN', Locked = true;
        SecretMissingErr: Label 'The %1 is not specified in the Rate Analyzer Setup.', Comment = '%1 = secret name';
        TwelveDataKeyNameLbl: Label 'Twelve Data API key';
        OANDATokenNameLbl: Label 'OANDA API token';
        DefaultBinanceBaseUrlTok: Label 'https://data-api.binance.vision', Locked = true;
        DefaultSignalExpirationsTok: Label '1,2,3,5,10,15', Locked = true;

    procedure GetPayoutPct(): Decimal
    begin
        GetRecordOnce();
        if "Payout %" <= 0 then
            exit(80);
        exit("Payout %");
    end;

    /// <summary>
    /// Hit rate in percent at which the expected profit of a trade is zero: win * payout = loss * stake.
    /// </summary>
    procedure GetBreakevenPct(): Decimal
    begin
        exit(Round(100 / (1 + GetPayoutPct() / 100), 0.01));
    end;

    procedure GetSignalExpirations(): Text
    begin
        GetRecordOnce();
        if "Signal Expirations (Min)" = '' then
            exit(DefaultSignalExpirationsTok);
        exit("Signal Expirations (Min)");
    end;

    procedure GetSignalBacktestCandles(): Integer
    begin
        GetRecordOnce();
        if "Signal Backtest Candles" <= 0 then
            exit(600);
        exit("Signal Backtest Candles");
    end;

    // The method parameter getters below do not read the database: forecast methods call them on the copy of the setup in the forecast context.
    // They fall back to defaults for setups created before the fields existed.

    procedure GetAROrder(): Integer
    begin
        if ("AR Order" < 1) or ("AR Order" > 5) then
            exit(2);
        exit("AR Order");
    end;

    procedure GetMeanReversionPeriod(): Integer
    begin
        if "Mean Reversion Period" < 5 then
            exit(20);
        exit("Mean Reversion Period");
    end;

    procedure GetMeanReversionZ(): Decimal
    begin
        if "Mean Reversion Z" <= 0 then
            exit(1);
        exit("Mean Reversion Z");
    end;

    procedure GetRSIPeriod(): Integer
    begin
        if "RSI Period" < 2 then
            exit(14);
        exit("RSI Period");
    end;

    procedure GetRSILevels(var Oversold: Decimal; var Overbought: Decimal)
    begin
        Oversold := "RSI Oversold";
        Overbought := "RSI Overbought";
        if (Oversold <= 0) or (Overbought >= 100) or (Oversold >= Overbought) then begin
            Oversold := 30;
            Overbought := 70;
        end;
    end;

    procedure GetStochasticPeriod(): Integer
    begin
        if "Stochastic Period" < 2 then
            exit(14);
        exit("Stochastic Period");
    end;

    procedure GetStochasticSmoothing(): Integer
    begin
        if "Stochastic Smoothing" < 1 then
            exit(3);
        exit("Stochastic Smoothing");
    end;

    procedure GetStochasticLevels(var Oversold: Decimal; var Overbought: Decimal)
    begin
        Oversold := "Stochastic Oversold";
        Overbought := "Stochastic Overbought";
        if (Oversold <= 0) or (Overbought >= 100) or (Oversold >= Overbought) then begin
            Oversold := 20;
            Overbought := 80;
        end;
    end;

    procedure GetEnsembleWeightCandles(): Integer
    begin
        if "Ensemble Weight Candles" < 10 then
            exit(100);
        exit("Ensemble Weight Candles");
    end;

    procedure GetLogisticTrainingCandles(): Integer
    begin
        if "Logistic Training Candles" < 50 then
            exit(1000);
        exit("Logistic Training Candles");
    end;

    procedure GetLogisticRefitInterval(): Integer
    begin
        if "Logistic Refit Interval" < 1 then
            exit(50);
        exit("Logistic Refit Interval");
    end;

    procedure GetLogisticMinProbability(): Decimal
    begin
        if ("Logistic Min. Probability %" <= 50) or ("Logistic Min. Probability %" >= 100) then
            exit(60);
        exit("Logistic Min. Probability %");
    end;

    /// <summary>
    /// Candles before the method window that composite and learning methods need: the weighting history of the weighted ensemble
    /// plus the training history of the logistic regression.
    /// </summary>
    procedure GetHistoryCandles(): Integer
    begin
        exit(GetEnsembleWeightCandles() + GetLogisticTrainingCandles());
    end;

    procedure GetTrackingIntervalMin(): Integer
    begin
        if "Tracking Interval (Min)" < 1 then
            exit(3);
        exit("Tracking Interval (Min)");
    end;

    procedure GetLearningDecay(): Decimal
    begin
        if ("Learning Decay" < 0.5) or ("Learning Decay" > 1) then
            exit(0.98);
        exit("Learning Decay");
    end;

    procedure GetMinLiveSamples(): Integer
    begin
        if "Min. Live Samples" < 1 then
            exit(20);
        exit("Min. Live Samples");
    end;

    procedure GetSignalMinSamples(): Integer
    begin
        GetRecordOnce();
        if "Signal Min. Samples" <= 0 then
            exit(50);
        exit("Signal Min. Samples");
    end;

    procedure GetBinanceBaseUrl(): Text
    begin
        GetRecordOnce();
        if "Binance Base URL" = '' then
            exit(DefaultBinanceBaseUrlTok);
        exit(DelChr("Binance Base URL", '>', '/ '));
    end;

    procedure GetRecordOnce()
    begin
        if RecordHasBeenRead then
            exit;
        InsertIfNotExists();
        RecordHasBeenRead := true;
    end;

    procedure InsertIfNotExists()
    begin
        Reset();
        if not Get() then begin
            Init();
            Insert(true);
        end;
    end;

    procedure SetTwelveDataApiKey(NewValue: SecretText)
    begin
        SetSecret(TwelveDataKeyTok, NewValue);
    end;

    procedure GetTwelveDataApiKey(): SecretText
    begin
        exit(GetSecret(TwelveDataKeyTok, TwelveDataKeyNameLbl));
    end;

    procedure HasTwelveDataApiKey(): Boolean
    begin
        exit(IsolatedStorage.Contains(TwelveDataKeyTok, DataScope::Company));
    end;

    procedure SetOANDAToken(NewValue: SecretText)
    begin
        SetSecret(OANDATokenTok, NewValue);
    end;

    procedure GetOANDAToken(): SecretText
    begin
        exit(GetSecret(OANDATokenTok, OANDATokenNameLbl));
    end;

    procedure HasOANDAToken(): Boolean
    begin
        exit(IsolatedStorage.Contains(OANDATokenTok, DataScope::Company));
    end;

    local procedure SetSecret(StorageKey: Text; NewValue: SecretText)
    begin
        if NewValue.IsEmpty() then begin
            if IsolatedStorage.Contains(StorageKey, DataScope::Company) then
                IsolatedStorage.Delete(StorageKey, DataScope::Company);
            exit;
        end;
        if EncryptionEnabled() then
            IsolatedStorage.SetEncrypted(StorageKey, NewValue, DataScope::Company)
        else
            IsolatedStorage.Set(StorageKey, NewValue, DataScope::Company);
    end;

    local procedure GetSecret(StorageKey: Text; SecretName: Text): SecretText
    var
        Value: SecretText;
    begin
        if not IsolatedStorage.Get(StorageKey, DataScope::Company, Value) then
            Error(SecretMissingErr, SecretName);
        exit(Value);
    end;
}
