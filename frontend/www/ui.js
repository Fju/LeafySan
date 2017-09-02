window.WebSocket = window.WebSocket || window.MozWebSocket;

function applyConfig(obj) {
	var key, config = liquidFillGaugeDefaultSettings();
	if (typeof obj !== 'object') return config
	for (key in obj) config[key] = obj[key];
	return config;
}

var lineChart = new LineChart('linechart');
function bindSelectButton(id, type) {
	document.getElementById(id).addEventListener('click', function() {
		lineChart.switchGraph(type);
	});
}
bindSelectButton('selectTemperature', 'temperature');
bindSelectButton('selectMoisture', 'moisture');
bindSelectButton('selectLight', 'brightness');
bindSelectButton('selectCo2', 'carbondioxide');

var refreshButton = document.getElementById('refresh'),
	dateInput = document.getElementById('date');

refreshButton.addEventListener('click', function() {
	var d = dateInput.value;
	if (d !== '') leafysan.fetch((new Date(d)).getTime());
});

var waterGauge = loadLiquidFillGauge("waterGauge", 0, applyConfig({
		waveAnimationTime: 2500,
		waveHeight: 0.125,
		waveRiseTime: 0,
		decimals: 1,
		unit: '%'
	})),
	lightGauge = loadLiquidFillGauge("lightGauge", 0, applyConfig({
		waveHeight: 0,
		waveAnimate: false,
		circleColor: "#dc9e04",
		textColor: "#000",
		waveTextColor: "rgba(255, 255, 255, 0.75)",
		waveColor: "#dc9e04",
		waveRiseTime: 0,
		minValue: 300,
		maxValue: 10000,
		unit: 'lx'
	})),
	tempGauge = loadLiquidFillGauge("tempGauge", 0, applyConfig({
		waveHeight: 0,
		waveAnimate: false,
		circleColor: "#f44336",
		textColor: "#000",
		waveTextColor: "rgba(255, 255, 255, 0.75)",
		waveColor: "#f44336",
		waveRiseTime: 0,
		minValue: 0,
		maxValue: 40,
		decimals: 1,
		unit: '°C'
	})),
	co2Gauge = loadLiquidFillGauge("co2Gauge", 0, applyConfig({
		waveHeight: 0,
		waveAnimate: false,
		circleColor: "#669900",
		textColor: "#000",
		waveTextColor: "rgba(255, 255, 255, 0.75)",
		waveColor: "#669900",
		waveRiseTime: 0,
		minValue: 0,
		maxValue: 5000,
		textSize: 0.6,
		unit: 'ppm'
	}));

var connection = new WebSocket('ws://' + location.hostname + ':' + '8080' + '/');

var leafysan = {
	updateId: 0,
	updateCycle: {
		start: function() {
			leafysan.updateId = setInterval(leafysan.updateCycle._, 1000);
		},
		quit: function() {
			clearInterval(leafysan.updateId);
		},
		_: function() {
			if (connection.readyState === 1) connection.send(JSON.stringify({ type: 'values' }));
			else leafysan.close();
		}
	},
	values: { temperature: 0, moisture: 0, brightness: 0, carbondioxide: 0 },
	fetch: function(date) {
		date = date || -1;
		connection.send(JSON.stringify({ type: 'archive', date: date }));
	},
	close: function() {
		connection.close();
		leafysan.updateCycle.quit();
		
		sweetAlert({
			title: 'Verbindung unterbrochen!', 
			text: 'Die Verbindung zum Server wurde unterbrochen. Laden Sie die Seite neu, um einen neuen Verbindungsaufbau zu ermöglichen', 
			type: 'error',
			showCancelButton: true,
			closeOnConfirm: false,
			confirmButtonText: 'Die Seite jetzt neu laden',
			cancelButtonText: 'Nein, danke',
			confirmButtonColor: '#ec6c62'
		}, function(e) {
			window.location.reload();
		});
	}
};


connection.onopen = function() {
	leafysan.updateCycle.start();
	leafysan.fetch();
};
connection.onerror = function(error) {
	// an error occurred when sending/receiving data
	console.log(error);
	leafysan.close();
};
connection.onclose = leafysan.close;

connection.onmessage = function(message) {
	try {		
		var json = JSON.parse(message.data);
		if (json.type === 'values') {
			for (var key in json.data) {
				leafysan.values[key] = parseFloat(json.data[key]);
			}
			waterGauge.update(leafysan.values.moisture);
			lightGauge.update(leafysan.values.brightness);
			tempGauge.update(leafysan.values.temperature);
			co2Gauge.update(leafysan.values.carbondioxide);
		} else if (json.type === 'archive') {
			if (json.data === '') {
				sweetAlert({
					title: 'Ups!', 
					text: 'Zu diesem Datum sind keine Daten auf dem Server vorhanden!', 
					type: 'error'
				});
			}
			else lineChart.parseData(json.data);	
		}
	} catch (e) {
		console.log(e);
	}
};
