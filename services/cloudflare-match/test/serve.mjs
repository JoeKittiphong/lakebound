import {runtime} from './runtime.mjs';
const mf=runtime(43843);console.log('TEST ONLY identity fixture + actual Durable Objects at '+await mf.ready);
process.on('SIGINT',async()=>{await mf.dispose();process.exit();});
