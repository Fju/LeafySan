'use strict';

const http				= require('http');
const fs				= require('fs');
const WebSocket			= require('ws');
const SerialPort		= require('serialport');
const commandLineArgs	= require('command-line-args')
 
const optionDefinitions = [
	{ name: 'list-serial-ports', alias: 'l', type: Boolean },
	{ name: 'serial-port', alias: 's', type: String, defaultValue: '/dev/ttyUSB0' },
	{ name: 'write-data', alias: 'd', type: Boolean },
	{ name: 'http-port', alias: 'h', type: Number, defaultValue: 8000 }
];

var config = commandLineArgs(optionDefinitions, { partial: true });
console.log(config);

if (config['list-serial-ports']) {
	SerialPort.list(function (err, ports) {
		if (err) console.log('Couldn\'t list serial ports');
		ports.forEach(function(port) {
			console.log(port.comName);
			console.log(port.pnpId);
			console.log(port.manufacturer);
		});
	});
}


const ID_BRIGHTNESS = 0;
const ID_MOISTURE = 1;
const ID_TEMPERATURE = 2;
const ID_CARBONDIOXIDE = 3;
var port = new SerialPort(config['serial-port'], { baudRate: 115200, autoOpen: false });

var dummies = {
		temperature: [], moisture: [], brightness: [], carbondioxide: [],
		toInt: function(array) {
			var temp = 0, i;
			for (i = 0; i != array.length; ++i) {
				if (array[i]) temp += array[i] << (i * 4);
			}
			return temp;
		}
	}, values = {
		temperature: 250, moisture: 430, brightness: 5550, carbondioxide: 2800
	};

port.open(function (err) {
	if (err) console.log(err);
});
port.on('readable', function () {
	var buf = port.read();
	buf.forEach((element) => {
		var id = element >> 6, shift = (element >> 4) & 3, data = element & 15, key;
		if (id === ID_BRIGHTNESS) key = 'brightness';
		else if (id === ID_MOISTURE) key = 'moisture';
		else if (id === ID_TEMPERATURE) key = 'temperature';
		else if (id === ID_CARBONDIOXIDE) key = 'carbondioxide';

		dummies[key][shift] = data;
		if (shift === 3) values[key] = dummies.toInt(dummies[key]); 
	});
});

setInterval(function() {
	if (!config['write-data']) return;

	var date = new Date(), path = 'data_' + date.getFullYear() + '-' + (1+date.getMonth()) + '-' + date.getDate() + '.csv';
	var copiedValues = {
		t: values.temperature / 10, m: (Math.min(1, Math.max(0, (values.moisture - 340) / (580 - 340))) * 100).toFixed(1), b: values.brightness, c: values.carbondioxide
	};
	if (!fs.existsSync(path)) {
		fs.writeFile(path, 'time,temperature,moisture,brightness,carbondioxide\n', (err) => {
			if (err) throw err;
			console.log('Created new data file succesfully!');			
		});
	}
	fs.readFile(path, (err, data) => {
		if (err) throw err;
		else {
			var newData = date.getHours() + ':' + date.getMinutes() + ':' + date.getSeconds() + ',' + copiedValues.t + ',' + copiedValues.m + ',' + copiedValues.b + ',' + copiedValues.c;
			console.log('Writing: ' + newData);
			fs.writeFile(path, data + newData + '\n', (e) => {
				if (e) throw e;
			});
		}
	});
}, 1000);


let server = http.createServer((req, res) => {
	var url = req.url;	

	//beautify URL, shows foo.bar when requested foo.bar/index.html
	if (url === '/index.html') {
		res.writeHead(301, {'Location': '/'});
		res.end();
		return;
	}
	if (url === '/') {
		url = '/index.html';
	}
	fs.readFile('./www' + url, (err, data) => {
		if (err) {
			res.writeHead(404);
			res.end('Error 404:\nPage not found\n');
		} else {
			let extension = url.slice(url.lastIndexOf('.') - url.length + 1);
			let mimeList = { html: 'text/html', less: 'text/css', css: 'text/css', svg: 'image/svg+xml', png: 'image/png', js: 'application/javascript' },
				mime = 'application/octet-stream';

			if (extension in mimeList) mime = mimeList[extension];

			res.writeHead(200, {'Content-Type': mime});
			res.end(data);
		}
	});
});
server.listen(config['http-port']);


const wss = new WebSocket.Server({ port: 8080 });

wss.on('connection', (ws, req) => {

	ws.on('message', (message) => {
		let json = JSON.parse(message);
		console.log(message);
		if (json.type === 'values') {
			ws.send(JSON.stringify({
				type: 'values',
				data: {
					brightness: values.brightness,
					moisture: (Math.min(1, Math.max(0, (values.moisture - 340) / (580 - 340))) * 100).toFixed(1),
					temperature: values.temperature / 10,
					carbondioxide: values.carbondioxide
				}
			}));
		} else if (json.type === 'archive') {
			var archivePath = 'data_test.csv';
			if (json.date > 0) {
				var date = new Date(json.date);
				var archivePath = 'data_' + date.getFullYear() + '-' + (1+date.getMonth()) + '-' + date.getDate() + '.csv';
			}  
			fs.readFile(archivePath, 'utf-8', (err, data) => {
				if (err) data = '';
				ws.send(JSON.stringify({
					type: 'archive',
					data: data
				}));
			});
		}
	});
});
