/* global LightweightCharts, Microsoft */

var rcChart = null;
var rcCandles = null;
var rcForecast = null;
var rcUpper = null;
var rcLower = null;
var rcPast = null;
var rcLegend = null;
var rcEmpty = null;
var rcTimer = null;
var rcFitted = false;
var rcOptions = { decimals: 5, pair: '' };

// Lightweight Charts shows times in UTC; shift them so the axis shows the browser's local time
function rcToLocal(unixSec) {
    return unixSec - new Date(unixSec * 1000).getTimezoneOffset() * 60;
}

function createRateChart() {
    var host = document.getElementById('controlAddIn');
    host.innerHTML = '';

    var wrap = document.createElement('div');
    wrap.className = 'rc-wrap';
    host.appendChild(wrap);

    rcLegend = document.createElement('div');
    rcLegend.className = 'rc-legend';
    wrap.appendChild(rcLegend);

    var container = document.createElement('div');
    container.className = 'rc-chart';
    wrap.appendChild(container);

    rcEmpty = document.createElement('div');
    rcEmpty.className = 'rc-empty';
    rcEmpty.textContent = 'Loading rates...';
    container.appendChild(rcEmpty);

    var footer = document.createElement('div');
    footer.className = 'rc-footer';
    footer.innerHTML =
        '<span>' +
        '<span class="rc-key"><span class="rc-swatch"></span>forecast</span>' +
        '<span class="rc-key"><span class="rc-swatch rc-band"></span>confidence band</span>' +
        '<span class="rc-key"><span class="rc-swatch rc-past"></span>earlier forecasts at horizon</span>' +
        '</span>' +
        '<a href="https://www.tradingview.com/" target="_blank" rel="noopener">Charts by TradingView</a>';
    wrap.appendChild(footer);

    var lc = LightweightCharts;
    rcChart = lc.createChart(container, {
        autoSize: true,
        layout: {
            background: { type: lc.ColorType.Solid, color: '#ffffff' },
            textColor: '#323130',
            fontSize: 12
        },
        grid: {
            vertLines: { color: '#f3f2f1' },
            horzLines: { color: '#f3f2f1' }
        },
        rightPriceScale: { borderVisible: false },
        timeScale: { borderVisible: false, timeVisible: true, secondsVisible: false, rightOffset: 8 },
        crosshair: { mode: lc.CrosshairMode.Normal }
    });

    rcCandles = rcChart.addCandlestickSeries({
        upColor: '#26a69a',
        downColor: '#ef5350',
        borderVisible: false,
        wickUpColor: '#26a69a',
        wickDownColor: '#ef5350'
    });

    rcPast = rcChart.addLineSeries({
        color: 'rgba(122, 122, 122, 0.9)',
        lineWidth: 1,
        lineStyle: lc.LineStyle.Dotted,
        priceLineVisible: false,
        lastValueVisible: false,
        crosshairMarkerVisible: false
    });

    var bandOptions = {
        color: 'rgba(255, 152, 0, 0.55)',
        lineWidth: 1,
        lineStyle: lc.LineStyle.Dashed,
        priceLineVisible: false,
        lastValueVisible: false,
        crosshairMarkerVisible: false
    };
    rcUpper = rcChart.addLineSeries(bandOptions);
    rcLower = rcChart.addLineSeries(bandOptions);

    rcForecast = rcChart.addLineSeries({
        color: '#ff9800',
        lineWidth: 2,
        lineStyle: lc.LineStyle.Dashed,
        priceLineVisible: false,
        lastValueVisible: true
    });

    rcApplyPrecision();
}

function rcApplyPrecision() {
    if (!rcChart) return;
    var d = rcOptions.decimals;
    var priceFormat = { type: 'price', precision: d, minMove: Math.pow(10, -d) };
    [rcCandles, rcPast, rcUpper, rcLower, rcForecast].forEach(function (s) {
        s.applyOptions({ priceFormat: priceFormat });
    });
}

// Lightweight Charts requires strictly ascending, unique times
function rcSortedUnique(points) {
    points.sort(function (a, b) { return a.time - b.time; });
    var result = [];
    points.forEach(function (p) {
        if (result.length && result[result.length - 1].time === p.time)
            result[result.length - 1] = p;
        else
            result.push(p);
    });
    return result;
}

function rcLine(rows, valueIndex) {
    return rcSortedUnique((rows || []).map(function (r) {
        return { time: rcToLocal(r[0]), value: r[valueIndex] };
    }));
}

function Init(options) {
    rcOptions = Object.assign(rcOptions, options || {});
    if (options && options.pair !== undefined)
        rcFitted = false;
    rcApplyPrecision();
}

function SetData(data) {
    if (!rcChart || !data) return;

    if (data.info && data.info.decimals !== undefined && data.info.decimals !== rcOptions.decimals) {
        rcOptions.decimals = data.info.decimals;
        rcApplyPrecision();
    }

    var candles = rcSortedUnique((data.candles || []).map(function (r) {
        return { time: rcToLocal(r[0]), open: r[1], high: r[2], low: r[3], close: r[4] };
    }));
    rcCandles.setData(candles);
    rcForecast.setData(rcLine(data.forecast, 1));
    rcLower.setData(rcLine(data.forecast, 2));
    rcUpper.setData(rcLine(data.forecast, 3));
    rcPast.setData(rcLine(data.pastForecast, 1));

    rcEmpty.style.display = candles.length ? 'none' : 'flex';
    rcEmpty.textContent = 'No rates loaded yet';

    if (!rcFitted && candles.length) {
        rcChart.timeScale().fitContent();
        rcFitted = true;
    }

    rcRenderLegend(data.info || {});
}

function SetAutoRefresh(enabled, intervalSec) {
    if (rcTimer) {
        clearInterval(rcTimer);
        rcTimer = null;
    }
    if (!enabled) return;
    var ms = Math.max(5, intervalSec || 15) * 1000;
    rcTimer = setInterval(function () {
        // skipIfBusy = true: do not queue refreshes while the server is still processing the previous one
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('OnRefreshRequested', [], true);
    }, ms);
}

function rcEscape(text) {
    var div = document.createElement('div');
    div.textContent = text === undefined || text === null ? '' : String(text);
    return div.innerHTML;
}

function rcFormatTime(unixSec) {
    if (!unixSec) return '';
    return new Date(unixSec * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

function rcRenderLegend(info) {
    var d = info.decimals !== undefined ? info.decimals : rcOptions.decimals;
    var fmt = function (v) { return typeof v === 'number' ? v.toFixed(d) : '-'; };
    var html = '<span class="rc-pair">' + rcEscape(info.pair) + '</span>' +
        '<span class="rc-muted">' + rcEscape(info.description) + '</span>' +
        '<span>Last: <b>' + fmt(info.lastClose) + '</b> <span class="rc-muted">' + rcFormatTime(info.lastTime) + '</span></span>';

    if (typeof info.forecastClose === 'number') {
        var change = info.changePct || 0;
        var cls = change > 0 ? 'rc-up' : (change < 0 ? 'rc-down' : 'rc-flat');
        var arrow = change > 0 ? '&#9650;' : (change < 0 ? '&#9660;' : '&#9654;');
        html += '<span>Forecast +' + rcEscape(info.horizonMin) + ' min (' + rcFormatTime(info.targetTime) + '): ' +
            '<span class="' + cls + '">' + arrow + ' ' + fmt(info.forecastClose) + ' (' + (change >= 0 ? '+' : '') + change.toFixed(3) + '%)</span></span>' +
            '<span class="rc-muted">band ' + fmt(info.lower) + ' &ndash; ' + fmt(info.upper) + '</span>';
    }

    html += '<span class="rc-muted">' + rcEscape(info.method) + ' &middot; ' + rcEscape(info.provider) + ' &middot; ' + rcEscape(info.timeframe) + '</span>' +
        '<span class="rc-muted">Direction hit rate: ' + rcEscape(info.hitRate) + '</span>';
    rcLegend.innerHTML = html;
}
