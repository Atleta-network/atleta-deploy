import { ApiPromise, WsProvider, Keyring } from '@polkadot/api';
import { cryptoWaitReady } from '@polkadot/util-crypto';
import fs from 'fs';

async function callSetCode(rpcUrl, sudoPrivateKey, wasmPath) {
    await cryptoWaitReady();

    const wsProvider = new WsProvider(rpcUrl);
    const api = await ApiPromise.create({ provider: wsProvider });
    const keyring = new Keyring({ type: 'ethereum' });
    const sudoAccount = keyring.addFromUri(sudoPrivateKey);

    const wasmBytes = fs.readFileSync(wasmPath, null).toString('hex');
    const call = api.tx.system.setCode(`0x${wasmBytes}`);
    const sudoCall = api.tx.sudo.sudoUncheckedWeight(call, {});

    const unsub = await sudoCall.signAndSend(sudoAccount, async (result) => {
        console.log(`Current status: ${result.status}`);

        if (result.status.isInBlock) {
            console.log(`Transaction included at blockHash ${result.status.asInBlock}`);
            unsub();
            await api.disconnect();
        }
    });

}

async function main() {
    const [, , rpcUrl, sudoPrivateKey, wasmPath] = process.argv;

    if (!rpcUrl || !sudoPrivateKey || !wasmPath) {
        console.error('Usage: node index.js <rpcUrl> <sudoPrivateKey> <wasmPath>');
        process.exit(1);
    }

    await callSetCode(rpcUrl, sudoPrivateKey, wasmPath);
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
