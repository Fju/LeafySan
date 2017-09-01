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
		unit: '%'
	})),
	lightGauge = loadLiquidFillGauge("lightGauge", 0, applyConfig({
		waveHeight: 0,
		waveAnimate: false,
		circleColor: "#dc9e04",
		textColor: "#000",
		waveTextColor: "#000",
		waveColor: "#fff075",
		waveRiseTime: 0,
		minValue: 300,
		maxValue: 10000,
		unit: 'lx'
	})),
	tempGauge = loadLiquidFillGauge("tempGauge", 0, applyConfig({
		waveHeight: 0,
		waveAnimate: false,
		circleColor: "#F44336",
		textColor: "#000",
		waveTextColor: "#000",
		waveColor: "#e9897b",
		displayPercent: false,
		waveRiseTime: 0,
		minValue: 10,
		maxValue: 50,
		unit: '°C'
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
	values: { temperature: 0, moisture: 0, brightness: 0 },
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
