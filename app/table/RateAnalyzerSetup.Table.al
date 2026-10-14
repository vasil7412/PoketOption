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
