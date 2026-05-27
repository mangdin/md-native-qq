import { NitroModules } from 'react-native-nitro-modules';
import type { MdNativeQQ } from './specs/MdNativeQQ.nitro';

export * from './specs/MdNativeQQ.nitro';

export const QQ = NitroModules.createHybridObject<MdNativeQQ>('MdNativeQQ');

export default QQ;
