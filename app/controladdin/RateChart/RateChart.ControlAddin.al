controladdin "SMA Rate Chart"
{
    RequestedHeight = 540;
    MinimumHeight = 360;
    VerticalStretch = true;
    VerticalShrink = true;
    HorizontalStretch = true;
    HorizontalShrink = true;

    Scripts =
        'app/controladdin/RateChart/lightweight-charts.standalone.production.js',
        'app/controladdin/RateChart/RateChart.js';
    StartupScript = 'app/controladdin/RateChart/Start.js';
    StyleSheets = 'app/controladdin/RateChart/RateChart.css';

    /// <summary>Raised when the chart is created and can receive data.</summary>
    event OnControlReady();
    /// <summary>Raised by the auto refresh timer. Skipped while the server is still busy with the previous refresh.</summary>
    event OnRefreshRequested();

    procedure Init(Options: JsonObject);
    procedure SetData(Data: JsonObject);
    procedure SetAutoRefresh(Enabled: Boolean; IntervalSec: Integer);
}
