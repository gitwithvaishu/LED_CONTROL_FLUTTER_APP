const express = require("express");
const WebSocket = require("ws");
const cors = require("cors");
const dotenv = require("dotenv");
const mongoose = require("mongoose");
const LEDStatus = require("./models/LedStatus.js");

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const MONGO_DB_URI = process.env.MONGO_DB_URI;

mongoose.connect(MONGO_DB_URI)
.then(()=>console.log("MongoDB connected"))
.catch((e)=>console.log("MongoDB Error: ",e.message));

const PORT = process.env.PORT || 3000;

const server = app.listen(PORT, ()=>{
    console.log(`Server running on port ${PORT}.`);
});

let currentStatus = {
    led: false,
    message: "Turned Off"
};

const getLEDStatus =async(req, res)=>{
    // try {
    //     statusVal = req.body;
    //     console.log("App: ",statusVal);
    //     const ledStat = await LEDStatus.create(statusVal); 
    //     res.status(200).json({message: ` ${ledStat}`});
    // } catch (error) {
    //     res.status(500).json({message: `Server Error: ${error.message}`});
    // }
    console.log("REQ BODY:", req.body);
    try {
        const { led } = req.body;

        if(typeof led != "boolean"){
            return res.status(400).json({message: "Invalid Type of data."});
        }

        currentStatus.led = led;
        currentStatus.message = led ? "Turned On" : "Turned Off";
        console.log("App: ", currentStatus);

        await LEDStatus.create(currentStatus);

        if(espClient && espClient.readyState === WebSocket.OPEN){
            espClient.send(JSON.stringify({
                type: "command",
                led: currentStatus.led
            }));
        }
        else{
            console.log("ESP8266 is not connected");
        }
        broadCastToFlutter({
            type: "update",
            ...currentStatus
        });

        res.status(200).json({message: currentStatus.message});
    } catch (error) {
        res.status(500).json({message: error.message});
    }
};

app.post('/toggle', getLEDStatus);

const wss = new WebSocket.Server({server});
console.log("Websocket server running");

let espClient = null;
let clients = new Set();

wss.on('connection', (ws, req) => {
    console.log("New WebSocket Connected");

    ws.on('message', (msg) =>{
        // const data = JSON.parse(msg);
        // if(data.device) {
        //     espClient = ws;
        //     console.log("Client connected.");
        // }
        // if(data.led){
        //     console.log("ESP32: ", data.led);
        //     if(data.led != status){
        //         ws.send(JSON.stringify({status}));
        //     }
        // }
        let data;
        try {
            data = JSON.parse(msg);    
        } catch (error) {
            console.log("Invalid JSOn received");
            return;
        }

        // ESP8266 register
        if(data.type === "register" && data.device === "esp8266"){
            espClient = ws;
            console.log("ESP8266 connected");

            currentStatus.led = false;
            currentStatus.message = "Turned Off";

            broadCastToFlutter({
                type: "esp_status",
                connected: true,
                message: "ESP8266 connected"
            });

            if(espClient.readyState === WebSocket.OPEN){
                espClient.send(JSON.stringify({
                    type: "command",
                    led : false
                }));
            }

            broadCastToFlutter({
                type: "update",
                ...currentStatus
            });

            return;
        }

        if(data.type === "flutter"){
            clients.add(ws);
            console.log("Flutter connected");
            ws.send(JSON.stringify({
                type: "update",
                ...currentStatus
            }));

            ws.send(JSON.stringify({
                type: "esp_status",
                connected: espClient !== null,
                message: espClient ? "ESP8266 Connected" : "ESP8266 Disconnected"
            }));
            return;
        }

        if(data.type === "status"){
            console.log("ESP8266 status: ", data);

            // currentStatus.led = data.led;
            // currentStatus.message =data.led ? "Turned On" : "Turned Off";

            // broadCastToFlutter({
            //     type: "update",
            //     ...currentStatus
            // });
        }

    });
    ws.on('close', ()=>{
        console.log("Client disconnected");
        if(ws == espClient){
            espClient = null;
            console.log("ESP8266 disconnected");

            broadCastToFlutter({
                type: "esp_status",
                connected: false,
                message: "ESP8266 Disconnected"
            });

            currentStatus.led = false;
            currentStatus.message = "Turned Off";

            broadCastToFlutter({
                type: "update",
                ...currentStatus
            });
        }
        clients.delete(ws);
    });
    ws.on('error', (e)=>{
        console.log("Websocket Error: ",e.message);
    });
});

function broadCastToFlutter(data){
    clients.forEach(client =>{
        if(client.readyState === WebSocket.OPEN){
            client.send(JSON.stringify(data));
        }
    });
}