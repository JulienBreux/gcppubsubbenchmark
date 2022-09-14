'use strict';

// topic:        projects/pubsub-benchmark/topics/node-topic
// subscription: node-subscription

const winston = require('winston');

const express = require('express');
const { PubSub } = require('@google-cloud/pubsub');

const app = express();
const port = 8080
const args = process.argv.slice(2);
const topic = process.env.TOPIC;
const subscription = process.env.SUBSCRIPTION;
const subscriptionTimeout = Number(process.env.SUBSCRIPTION_TIMEOUT);
const projectId = process.env.PROJECT_ID;

//+GOOGLE_APPLICATION_CREDENTIALS

const { LoggingWinston } = require('@google-cloud/logging-winston');
const loggingWinston = new LoggingWinston();

const logger = winston.createLogger({
    level: 'info',
    format: winston.format.json(),
    transports: [
        new winston.transports.Console(),
        loggingWinston,
    ],
});

const pubsub = new PubSub({ projectId });

app.disable('x-powered-by');

// API Handler (Publish)
app.get('/', async(req, res) => {
    const now = Date.now();
    const data = JSON.stringify({ createdAt: now });
    const dataBuffer = Buffer.from(data);

    try {
        const messageId = await pubsub
            .topic(topic)
            .publishMessage({ data: dataBuffer });
        logger.info(`message ${messageId} published at ${now}`, { topic: topic, createdAt: now, id: messageId });

        res.status(201);
        res.json({ published: "success", id: messageId });
    } catch (error) {
        logger.error('received error while publishing', { topic: topic, error: error.message });
        // process.exitCode = 1;
        res.status(500);
        res.json({ published: "error", error: error.message });
    }
})

// Message Handler (subscribe)
let messageCount = 0;
const messageHandler = message => {
    const buffer = Buffer.from(message.data, 'base64');
    const data = buffer ? JSON.parse(buffer.toString()) : null;

    const now = Date.now();
    const duration = now - data.createdAt;

    logger.info(data.createdAt)
    logger.info(`received message`, { createdAt: data.createdAt, receivedAt: now, duration: duration, id: message.id, data: data, attributes: message.attributes });
    messageCount += 1;

    message.ack();
};

// Start Publish (API server) or Subscribe (worker)
switch (args[0]) {
    // Publish API
    case 'publish':
        const server = app.listen(port, () => {
            logger.info(`listening on port ${port}, GET / to publish`, { port });
        });
        listenSigs(() => {
            server.close(() => {
                logger.info('HTTP server closed');
            });
        });
        break;
    case 'subscribe':
        const sub = pubsub.subscription(subscription);
        sub.on(`message`, messageHandler);
        listenSigs(() => {
            sub.removeListener('message', messageHandler);
            logger.info('listener removed');
        });
        if (subscriptionTimeout > 0) {
            setTimeout(() => {
                sub.removeListener('message', messageHandler);
                logger.info(`${messageCount} message(s) received`, { messageCount });
            }, subscriberTimeout * 1000);
        }
        logger.info(`waiting message`, { subscription });
        break;
    default:
        logger.error('usage: node index.js publish|subscribe');
}

function shutdown(signal, callback) {
    return (err) => {
        logger.info(`${signal} signal received`);
        callback(signal);
        setTimeout(() => {
            console.log('...waited 5s, exiting.');
            process.exit(err ? 1 : 0);
        }, 5000).unref();
    };
}

function listenSigs(callback) {
    process
        .on('SIGTERM', shutdown('SIGTERM', callback))
        .on('SIGINT', shutdown('SIGINT', callback))
        .on('uncaughtException', shutdown('uncaughtException', callback));
}