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

var controls = {
	btn_applyThresholds:	document.getElementById('btn_applyThresholds'),
	btn_getData:			document.getElementById('btn_getData'),
	lbl_temperature:		document.getElementById('lbl_temperature'),
	lbl_brightness:			document.getElementById('lbl_brightness'),
	lbl_moisture:			document.getElementById('lbl_moisture'),
	lbl_co2:				document.getElementById('lbl_co2'),
	lbl_heatingOn:			document.getElementById('lbl_heatingOn'),
	lbl_wateringOn:			document.getElementById('lbl_wateringOn'),
	lbl_lightingOn:			document.getElementById('lbl_lightingOn'),
	lbl_ventilationOn:		document.getElementById('lbl_ventilationOn'),
	input_threshHeating:	document.getElementById('input_threshHeating'),
	input_threshWatering:	document.getElementById('input_threshWatering'),
	input_threshLighting:	document.getElementById('input_threshLighting')
}



var refreshButton = document.getElementById('refresh'),
	dateInput = document.getElementById('date');

refreshButton.addEventListener('click', function() {
	var d = dateInput.value;
	if (d !== '') leafysan.fetch((new Date(d)).getTime());
});

btn_applyThresholds.addEventListener('click', function(e) {
	var t = parseFloat(controls.input_threshHeating.value),
		m = parseFloat(controls.input_threshWatering.value),
		b = parseInt(controls.input_threshLighting.value);

	var data = {};

	if (!isNaN(t)) data.temperature = t;
	if (!isNaN(m)) data.moisture = m;
	if (!isNaN(b)) data.brightness = b;

	connection.send(JSON.stringify({ type: 'thresholds', data: data }));
});

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
	values: { temperature: 0, moisture: 0, brightness: 0, co2: 0, heating: 0, watering: 0, lighting: 0, ventilation: 0 },
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
		}, function(confirmed) {
			if (confirmed) window.location.reload();
		});
	},
	updateGUI: function() {
		controls.lbl_temperature.textContent	= leafysan.values.temperature.toFixed(1) + ' °C';
		controls.lbl_brightness.textContent		= leafysan.values.brightness + ' lx';
		controls.lbl_moisture.textContent		= leafysan.values.moisture.toFixed(1) + ' %';
		controls.lbl_co2.textContent			= leafysan.values.co2 + ' ppm';

		controls.lbl_heatingOn.setAttribute('active', leafysan.values.heating === 1);
		controls.lbl_wateringOn.setAttribute('active', leafysan.values.watering === 1);
		controls.lbl_lightingOn.setAttribute('active', leafysan.values.lighting === 1);
		controls.lbl_ventilationOn.setAttribute('active', leafysan.values.ventilation === 1);
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
			leafysan.updateGUI();
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
