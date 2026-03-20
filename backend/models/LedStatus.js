const mongoose = require("mongoose");

const ledSchema = new mongoose.Schema({
    led: {
        type: Boolean,
        required: true
    },
    message: {
        type:String
    },
    createdAt: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model("LedStatus", ledSchema);