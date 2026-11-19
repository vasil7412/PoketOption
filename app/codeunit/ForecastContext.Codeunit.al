/// <summary>
/// Candle history the forecast methods work on. Position is the index of the base candle the forecast is built at,
/// the window are the Lookback candles ending at Position. Methods may only read candles up to Position.
/// Also caches forecasts per method and position, so composite methods and walk-forward tests do not repeat work.
/// </summary>
codeunit 50117 "SMA Forecast Context"
{
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        Opens: List of [Decimal];
        Highs: List of [Decimal];
        Lows: List of [Decimal];
        Closes: List of [Decimal];
        Times: List of [DateTime];
        Completes: List of [Boolean];
        CachedPoints: Dictionary of [BigInteger, List of [Decimal]];
        CachedSigmas: Dictionary of [BigInteger, List of [Decimal]];
        MethodStates: Dictionary of [Text, List of [Decimal]];
        CurrentPosition: Integer;
        LookbackCandles: Integer;
        LoadedPairCode: Code[20];
        LoadedTimeframe: Enum "SMA Rate Timeframe";

    /// <summary>
    /// Loads the latest MaxCount candles of the pair, oldest first, and sets the position to the newest one.
    /// </summary>
    procedure Load(CurrencyPair: Record "SMA Currency Pair"; MaxCount: Integer; OnlyComplete: Boolean)
    var
        RateCandle: Record "SMA Rate Candle";
    begin
        Clear(Opens);
        Clear(Highs);
        Clear(Lows);
        Clear(Closes);
        Clear(Times);
        Clear(Completes);
        ClearCache();
        RateAnalyzerSetup.GetRecordOnce();
        LookbackCandles := RateAnalyzerSetup."Lookback Candles";
        CurrentPosition := 0;
        LoadedPairCode := CurrencyPair.Code;
        LoadedTimeframe := CurrencyPair.Timeframe;

        RateCandle.SetRange("Pair Code", CurrencyPair.Code);
        RateCandle.SetRange(Timeframe, CurrencyPair.Timeframe);
        if OnlyComplete then
            RateCandle.SetRange(Complete, true);
        RateCandle.SetLoadFields(Open, High, Low, Close, Complete);
#pragma warning disable AA0181, AA0233
        if not RateCandle.FindLast() then
            exit;
        // step back from the newest candle to read the latest MaxCount candles in ascending order
        if MaxCount > 1 then
            RateCandle.Next(-(MaxCount - 1));
#pragma warning restore AA0181, AA0233
        repeat
            Opens.Add(RateCandle.Open);
            Highs.Add(RateCandle.High);
            Lows.Add(RateCandle.Low);
            Closes.Add(RateCandle.Close);
            Times.Add(RateCandle."Open Time");
            Completes.Add(RateCandle.Complete);
        until RateCandle.Next() = 0;
        CurrentPosition := Closes.Count();
    end;

    /// <summary>
    /// Copy of the setup read when the history was loaded. Read method parameters from it instead of the database.
    /// </summary>
    procedure GetSetup(var NewRateAnalyzerSetup: Record "SMA Rate Analyzer Setup")
    begin
        NewRateAnalyzerSetup := RateAnalyzerSetup;
    end;

    procedure PairCode(): Code[20]
    begin
        exit(LoadedPairCode);
    end;

    procedure PairTimeframe(): Enum "SMA Rate Timeframe"
    begin
        exit(LoadedTimeframe);
    end;

    procedure CandleCount(): Integer
    begin
        exit(Closes.Count());
    end;

    procedure SetPosition(NewPosition: Integer)
    begin
        CurrentPosition := NewPosition;
    end;

    procedure Position(): Integer
    begin
        exit(CurrentPosition);
    end;

    procedure SetLookback(NewLookback: Integer)
    begin
        LookbackCandles := NewLookback;
        ClearCache();
    end;

    procedure Lookback(): Integer
    begin
        exit(LookbackCandles);
    end;

    procedure WindowStart(): Integer
    var
        Start: Integer;
    begin
        Start := CurrentPosition - LookbackCandles + 1;
        if Start < 1 then
            Start := 1;
        exit(Start);
    end;

    /// <summary>
    /// Close prices of the window, oldest first.
    /// </summary>
    procedure WindowCloses(): List of [Decimal]
    var
        Empty: List of [Decimal];
    begin
        if CurrentPosition < 1 then
            exit(Empty);
        exit(Closes.GetRange(WindowStart(), CurrentPosition - WindowStart() + 1));
    end;

    procedure OpenAt(Index: Integer): Decimal
    begin
        exit(Opens.Get(Index));
    end;

    procedure HighAt(Index: Integer): Decimal
    begin
        exit(Highs.Get(Index));
    end;

    procedure LowAt(Index: Integer): Decimal
    begin
        exit(Lows.Get(Index));
    end;

    procedure CloseAt(Index: Integer): Decimal
    begin
        exit(Closes.Get(Index));
    end;

    procedure TimeAt(Index: Integer): DateTime
    begin
        exit(Times.Get(Index));
    end;

    procedure IsComplete(Index: Integer): Boolean
    begin
        exit(Completes.Get(Index));
    end;

    /// <summary>
    /// Returns the cached forecast of the method at the current position. The returned lists are shared with the cache: do not modify them.
    /// </summary>
    procedure TryGetCached(MethodOrdinal: Integer; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal]): Boolean
    var
        CacheKey: BigInteger;
    begin
        CacheKey := GetCacheKey(MethodOrdinal);
        if not CachedPoints.Get(CacheKey, Points) then
            exit(false);
        if Points.Count() < Steps then
            exit(false);
        exit(CachedSigmas.Get(CacheKey, Sigmas));
    end;

    procedure SetCached(MethodOrdinal: Integer; Points: List of [Decimal]; Sigmas: List of [Decimal])
    var
        CacheKey: BigInteger;
    begin
        CacheKey := GetCacheKey(MethodOrdinal);
        CachedPoints.Set(CacheKey, Points);
        CachedSigmas.Set(CacheKey, Sigmas);
    end;

    /// <summary>
    /// Free-form storage for methods that keep state between positions, such as fitted models or per-candle features.
    /// Prefix the key with a method tag. The stored list is shared: do not modify it after storing or reading.
    /// </summary>
    procedure TryGetMethodState(StateKey: Text; var Values: List of [Decimal]): Boolean
    begin
        exit(MethodStates.Get(StateKey, Values));
    end;

    procedure SetMethodState(StateKey: Text; Values: List of [Decimal])
    begin
        MethodStates.Set(StateKey, Values);
    end;

    procedure ClearCache()
    begin
        Clear(CachedPoints);
        Clear(CachedSigmas);
        Clear(MethodStates);
    end;

    local procedure GetCacheKey(MethodOrdinal: Integer): BigInteger
    var
        CacheKey: BigInteger;
    begin
        CacheKey := MethodOrdinal;
        exit(CacheKey * 100000000 + CurrentPosition);
    end;
}
