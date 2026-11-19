/// <summary>
/// Autoregression of candle changes: the next change is predicted from the previous AR Order changes.
/// Coefficients are fitted by ridge least squares on the window, so the method finds by itself whether moves
/// tend to continue (positive coefficients) or to reverse (negative coefficients). No drift is assumed.
/// </summary>
codeunit 50119 "SMA Autoregression Fcst" implements "SMA IForecast Method"
{
    Access = Internal;

    var
        ForecastMath: Codeunit "SMA Forecast Math";

    procedure Forecast(var ForecastContext: Codeunit "SMA Forecast Context"; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal])
    var
        RateAnalyzerSetup: Record "SMA Rate Analyzer Setup";
        Series: List of [Decimal];
        Changes: List of [Decimal];
        Z: List of [Decimal];
        A: array[5, 5] of Decimal;
        B: array[5] of Decimal;
        Phi: array[5] of Decimal;
        ChangeMean: Decimal;
        ChangeStdDev: Decimal;
        Predicted: Decimal;
        Residual: Decimal;
        SumSquares: Decimal;
        ResidualSigma: Decimal;
        Price: Decimal;
        Order: Integer;
        n: Integer;
        m: Integer;
        t: Integer;
        i: Integer;
        j: Integer;
        Step: Integer;
        Equations: Integer;
    begin
        Clear(Points);
        Clear(Sigmas);
        ForecastContext.GetSetup(RateAnalyzerSetup);
        Order := RateAnalyzerSetup.GetAROrder();
        Series := ForecastContext.WindowCloses();
        n := Series.Count();
        m := n - 1;
        if m < Order + 10 then
            exit;

        for t := 2 to n do
            Changes.Add(Series.Get(t) - Series.Get(t - 1));
        ChangeMean := ForecastMath.Mean(Changes, 1, m);
        ChangeStdDev := ForecastMath.StdDev(Changes, 1, m);
        Price := Series.Get(n);
        if ChangeStdDev = 0 then begin
            AddFlat(Price, Steps, Points, Sigmas);
            exit;
        end;

        // work on standardized changes to keep the numbers well scaled
        for t := 1 to m do
            Z.Add((Changes.Get(t) - ChangeMean) / ChangeStdDev);

        for t := Order + 1 to m do begin
            for i := 1 to Order do begin
                B[i] += Z.Get(t - i) * Z.Get(t);
                for j := 1 to Order do
                    A[i, j] += Z.Get(t - i) * Z.Get(t - j);
            end;
            Equations += 1;
        end;
        // ridge shrinks the coefficients towards zero, so noise in a short window does not create a strong signal
        for i := 1 to Order do
            A[i, i] += Equations * 0.05;
        if not Solve(A, B, Order, Phi) then begin
            AddFlat(Price, Steps, Points, Sigmas);
            exit;
        end;

        for t := Order + 1 to m do begin
            Predicted := 0;
            for i := 1 to Order do
                Predicted += Phi[i] * Z.Get(t - i);
            Residual := Z.Get(t) - Predicted;
            SumSquares += Residual * Residual;
        end;
        ResidualSigma := ForecastMath.Sqrt(SumSquares / Equations) * ChangeStdDev;

        for Step := 1 to Steps do begin
            Predicted := 0;
            for i := 1 to Order do
                Predicted += Phi[i] * Z.Get(Z.Count() - i + 1);
            Z.Add(Predicted);
            Price += Predicted * ChangeStdDev;
            Points.Add(Price);
            Sigmas.Add(ResidualSigma * ForecastMath.Sqrt(Step));
        end;
    end;

    local procedure AddFlat(Price: Decimal; Steps: Integer; var Points: List of [Decimal]; var Sigmas: List of [Decimal])
    var
        Step: Integer;
    begin
        for Step := 1 to Steps do begin
            Points.Add(Price);
            Sigmas.Add(0);
        end;
    end;

    /// <summary>
    /// Solves A * X = B by Gaussian elimination with partial pivoting. A and B are destroyed.
    /// </summary>
    local procedure Solve(var A: array[5, 5] of Decimal; var B: array[5] of Decimal; Size: Integer; var X: array[5] of Decimal): Boolean
    var
        Factor: Decimal;
        Swap: Decimal;
        Sum: Decimal;
        Pivot: Integer;
        Col: Integer;
        Row: Integer;
        c: Integer;
    begin
        for Col := 1 to Size do begin
            Pivot := Col;
            for Row := Col + 1 to Size do
                if Abs(A[Row, Col]) > Abs(A[Pivot, Col]) then
                    Pivot := Row;
            if Abs(A[Pivot, Col]) < 0.000000001 then
                exit(false);
            if Pivot <> Col then begin
                for c := 1 to Size do begin
                    Swap := A[Col, c];
                    A[Col, c] := A[Pivot, c];
                    A[Pivot, c] := Swap;
                end;
                Swap := B[Col];
                B[Col] := B[Pivot];
                B[Pivot] := Swap;
            end;
            for Row := Col + 1 to Size do begin
                Factor := A[Row, Col] / A[Col, Col];
                for c := Col to Size do
                    A[Row, c] -= Factor * A[Col, c];
                B[Row] -= Factor * B[Col];
            end;
        end;
        for Row := Size downto 1 do begin
            Sum := B[Row];
            for c := Row + 1 to Size do
                Sum -= A[Row, c] * X[c];
            X[Row] := Sum / A[Row, Row];
        end;
        exit(true);
    end;
}
