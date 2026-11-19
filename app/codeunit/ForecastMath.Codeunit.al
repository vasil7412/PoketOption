codeunit 50114 "SMA Forecast Math"
{
    Access = Internal;

    procedure Sqrt(Value: Decimal): Decimal
    begin
        if Value <= 0 then
            exit(0);
        exit(Power(Value, 0.5));
    end;

    procedure Sign(Value: Decimal): Integer
    begin
        if Value > 0 then
            exit(1);
        if Value < 0 then
            exit(-1);
        exit(0);
    end;

    /// <summary>
    /// Standard deviation of one-candle price changes. Under a random walk the error of an h-step forecast grows as this value * sqrt(h).
    /// </summary>
    procedure ChangeStdDev(Series: List of [Decimal]): Decimal
    var
        Change: Decimal;
        SumChange: Decimal;
        SumSquares: Decimal;
        MeanChange: Decimal;
        n: Integer;
        i: Integer;
    begin
        n := Series.Count() - 1;
        if n < 2 then
            exit(0);
        for i := 2 to Series.Count() do begin
            Change := Series.Get(i) - Series.Get(i - 1);
            SumChange += Change;
            SumSquares += Change * Change;
        end;
        MeanChange := SumChange / n;
        exit(Sqrt((SumSquares - n * MeanChange * MeanChange) / (n - 1)));
    end;

    /// <summary>
    /// Mean of Series items FromIndex..ToIndex.
    /// </summary>
    procedure Mean(Series: List of [Decimal]; FromIndex: Integer; ToIndex: Integer): Decimal
    var
        Sum: Decimal;
        i: Integer;
    begin
        if ToIndex < FromIndex then
            exit(0);
        for i := FromIndex to ToIndex do
            Sum += Series.Get(i);
        exit(Sum / (ToIndex - FromIndex + 1));
    end;

    /// <summary>
    /// Sample standard deviation of Series items FromIndex..ToIndex.
    /// </summary>
    procedure StdDev(Series: List of [Decimal]; FromIndex: Integer; ToIndex: Integer): Decimal
    var
        Average: Decimal;
        SumSquares: Decimal;
        i: Integer;
    begin
        if ToIndex - FromIndex < 1 then
            exit(0);
        Average := Mean(Series, FromIndex, ToIndex);
        for i := FromIndex to ToIndex do
            SumSquares += (Series.Get(i) - Average) * (Series.Get(i) - Average);
        exit(Sqrt(SumSquares / (ToIndex - FromIndex)));
    end;

    procedure Exp(Value: Decimal): Decimal
    begin
        exit(Power(2.718281828459045, Value));
    end;

    /// <summary>
    /// Standard normal cumulative distribution (Abramowitz-Stegun 7.1.26, error below 1.5e-7).
    /// </summary>
    procedure NormalCdf(Value: Decimal): Decimal
    var
        y: Decimal;
        t: Decimal;
        Poly: Decimal;
    begin
        if Value < 0 then
            exit(1 - NormalCdf(-Value));
        y := Value / 1.414213562373095;
        t := 1 / (1 + 0.3275911 * y);
        Poly := t * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
        exit(0.5 * (2 - Poly * Exp(-y * y)));
    end;

    /// <summary>
    /// Value z with NormalCdf(z) = Probability, found by bisection.
    /// </summary>
    procedure NormalQuantile(Probability: Decimal): Decimal
    var
        Low: Decimal;
        High: Decimal;
        Middle: Decimal;
        i: Integer;
    begin
        Low := -10;
        High := 10;
        for i := 1 to 60 do begin
            Middle := (Low + High) / 2;
            if NormalCdf(Middle) < Probability then
                Low := Middle
            else
                High := Middle;
        end;
        exit((Low + High) / 2);
    end;

    /// <summary>
    /// Lower bound of the Wilson score interval for Hits out of Samples, with Z standard deviations (1.645 = 95% one-sided).
    /// </summary>
    procedure WilsonLowerBound(Hits: Integer; Samples: Integer; Z: Decimal): Decimal
    var
        p: Decimal;
        z2: Decimal;
        n: Decimal;
    begin
        if Samples <= 0 then
            exit(0);
        n := Samples;
        p := Hits / n;
        z2 := Z * Z;
        exit((p + z2 / (2 * n) - Z * Sqrt(p * (1 - p) / n + z2 / (4 * n * n))) / (1 + z2 / n));
    end;

    /// <summary>
    /// Forecast of an indicator rule: a move of (0.5 + Fraction) typical candle changes in Direction (-1, 0, 1), growing with sqrt(step).
    /// </summary>
    procedure IndicatorForecast(Price: Decimal; Direction: Integer; Fraction: Decimal; StepSigma: Decimal; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal])
    var
        Step: Integer;
    begin
        Clear(Points);
        Clear(Sigmas);
        if Fraction < 0 then
            Fraction := 0;
        if Fraction > 1 then
            Fraction := 1;
        for Step := 1 to Steps do begin
            Points.Add(Price + Direction * (0.5 + Fraction) * StepSigma * Sqrt(Step));
            Sigmas.Add(StepSigma * Sqrt(Step));
        end;
    end;
}
