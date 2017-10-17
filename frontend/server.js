'use strict';

const http				= require('http');
const fs				= require('fs');
const WebSocket			= require('ws');
const SerialPort		= require('serialport');
const commandLineArgs	= require('command-line-args')

// -----------------------------
// command line argument parsing
// -----------------------------
const optionDefinitions = [
	{ name: 'list-serial-ports', alias: 'l', type: Boolean },
	{ name: 'serial-port', alias: 's', type: String, defaultValue: '/dev/ttyUSB0' },
	{ name: 'write-data', alias: 'd', type: Boolean },
	{ name: 'http-port', alias: 'h', type: Number, defaultValue: 8000 }
];
var config = commandLineArgs(optionDefinitions, { partial: true });
if (config['list-serial-ports']) {
	SerialPort.list(function (err, ports) {
		if (err) console.log('Couldn\'t list serial ports');
		ports.forEach(function(port) {
			console.log(port.comName);
			console.log(port.pnpId);
			console.log(port.manufacturer);
		});
	});
} else {
	console.log('Listening to', config['serial-port']);
}

const PROTOCOL_START_CMD	= 0x40; // 0100 0000
const PROTOCOL_DATA_CMD		= 0x80; // 1000 0000
const PROTOCOL_DATA_ALT_CMD	= 0xC0; // 1100 0000
const PROTOCOL_END_CMD		= 0x3F; // 0011 1111
const PROTOCOL_LIGHTING_ID	= 0x00; // 0000 0000
const PROTOCOL_WATERING_ID	= 0x01; // 0000 0001
const PROTOCOL_HEATING_ID	= 0x02; // 0000 0010
const PROTOCOL_CO2_ID		= 0x03; // 0000 0011
const PROTOCOL_SEND_BYTES	= 9;	// amount of bytes to be sent

var values = { temp: 0, moisture: 0, brightness: 0, co2: 0 };
var thresholds = { temp: 22.0, moisture: 50.0, brightness: 400 };

var port = new SerialPort(config['serial-port'], { baudRate: 115200 }),
	started, completeData, prevCmd, bitShift, index;
port.on('error', (err) => {
	console.log('Error: Something went wrong reading the serial port!\n' + err);
});
port.on('data', (data) => {
	console.log(data);
	data.forEach((element) => {
		if (element === PROTOCOL_START_CMD) {
			started = true;
			prevCmd = 0;
			bitShift = 0;
			index = 0;
			completeData = [];
		} else if (element === PROTOCOL_END_CMD) {
			started = false;
			if (completeData.length !== 0) {
				// parse dataset
				var i, item;
				for (i = 0; i != completeData.length; ++i) {
					item = completeData[i];
					if (item & 0x03 === PROTOCOL_LIGHTING_ID) {
						values.brightness = item >> 2;		
					} else if (item & 0x03 === PROTOCOL_WATERING_ID) {
						values.moisture = item >> 2;
					} else if (item & 0x03 === PROTOCOL_HEATING_ID) {
						values.temp = item >> 2;
					} else if (item & 0x03 === PROTOCOL_CO2_ID) {
						values.co2 = item >> 2;
					}
				}
			} else console.log('Received invalid dataset :/');
		} else if (started) {
			var newCmd = (element && 0xC0) >> 6;
			if (!prevCmd) prevCmd = newCmd;
			if (prevCmd !== newCmd) {
				bitShift = 0;
				index++;
			}
			if (index <= 4) completeData[index] = completeData[index] | ((element & 0x3F) << (6 * bitShift++));
		}
	});
});
function parseData() {
	console.log(values);
}

setInterval(function() {
	//send 
	var buf = Buffer.from([PROTOCOL_START_CMD, 0, 0, 0, 0, 0, 0, 0, 0, 0, PROTOCOL_END_CMD]), s = 0, i, shift = 0, prefix, data, value;
	for (i = 0; i != PROTOCOL_SEND_BYTES; ++i) {
		if (s % 2 === 0) prefix = PROTOCOL_DATA_CMD;
		else prefix = PROTOCOL_DATA_ALT_CMD;

		if (s === PROTOCOL_LIGHTING_ID) value = thresholds.brightness;
		else if (s === PROTOCOL_WATERING_ID) value = Math.floor(thresholds.moisture * 10);
		else if (s === PROTOCOL_HEATING_ID) value = Math.floor(thresholds.temp * 10);

		if (shift === 2) data = ((value & 0x0F) << 2) | s;
		else data = (value >> (4 + (1-shift) * 6)) & 0x3F;
		buf.writeUInt8(prefix | data, 1 + i);

		if (i % 3 === 2) {
			//reset shift, move to next threshold value
			shift = 0;
			s++;
		} else shift++;
	}
	// send thresholds to DE2-Board
	port.write(buf);

	if (!config['write-data']) return; // don't write data

	var date = new Date(),
		path = 'data/data_' + date.getFullYear() + '-' + (1+date.getMonth()) + '-' + date.getDate() + '.csv',
		v = {
			t: (values.temp * 0.1).toFixed(1),
			m: (values.moisture * 0.1).toFixed(1),
			b: values.brightness,
			c: values.carbondioxide
		},
		d = date.getHours() + ':' + date.getMinutes() + ':' + date.getSeconds();

	fs.readFile(path, 'utf-8', (err, fileContent) => {
		if (err) fileContent = 'time,temperature,moisture,brightness,carbondioxide\n'; // write csv header
		value = ([d, v.t, v.m, v.b, v.c]).join(',');
		fs.writeFile(path, fileContent + value + '\n', (err) => {
			if (err) throw err;
			console.log('written', path, value);		
		});
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
		//console.log(message);
		if (json.type === 'values') {
			ws.send(JSON.stringify({
				type: 'values',
				data: {
					brightness: values.brightness,
					moisture: (values.moisture * 0.1).toFixed(1),
					temperature: (values.temp * 0.1).toFixed(1),
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
		} else if (json.type === 'thresholds') {
			thresholds.changed = true;
			var a = parseFloat(json.temp), b = parseFloat(json.moisture), c = parseInt(json.brightness);
			if (!isNaN(a) && a >= 0 && a <= 30) thresholds.temp = Math.round(a, 1);
			if (!isNaN(b) && b >= 0 && b <= 100) thresholds.moisture = Math.round(b, 1);
			if (!isNaN(c) && c >= 0 && c <= 40000) thresholds.brightness = c;
		}
	});
});
