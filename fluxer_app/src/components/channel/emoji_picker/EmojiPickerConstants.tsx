/*
 * Copyright (C) 2026 Fluxer Contributors
 *
 * This file is part of Fluxer.
 *
 * Fluxer is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Fluxer is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with Fluxer. If not, see <https://www.gnu.org/licenses/>.
 */

import RuntimeConfigStore from '@app/stores/RuntimeConfigStore';
import {convertToCodePoints} from '@app/utils/EmojiCodepointUtils';

export const EMOJI_CLAP = '\u{1F44F}';
export const EMOJI_SPRITE_SIZE = 32;
export const EMOJI_ROW_HEIGHT = 48;
export const EMOJI_PICKER_CUSTOM_EMOJI_SIZE = 48;
export const CATEGORY_HEADER_HEIGHT = 32;
export const EMOJIS_PER_ROW = 9;
export const OVERSCAN_ROWS = 5;

interface SpriteSheetOptions {
	retina?: boolean;
}

const SPRITE_VERSION = '2';
const SPRITE_SHEET_NAMES: Record<string, string> = {
	default: 'spritesheet-emoji',
	'1f3fb': 'spritesheet-1f3fb',
	'1f3fc': 'spritesheet-1f3fc',
	'1f3fd': 'spritesheet-1f3fd',
	'1f3fe': 'spritesheet-1f3fe',
	'1f3ff': 'spritesheet-1f3ff',
};

const getSpriteBase = (): string => {
	const cdnBase = RuntimeConfigStore.staticCdnEndpoint || 'https://fluxerstatic.com';
	return `${cdnBase}/emoji`;
};

const buildVersionedSpriteUrl = (fileName: string): string => {
	const url = new URL(`${getSpriteBase()}/${fileName}`);
	url.searchParams.set('v', SPRITE_VERSION);
	return url.toString();
};

const getSpriteSheetKey = (skinTone?: string): string => {
	if (!skinTone) {
		return 'default';
	}
	const codepoint = convertToCodePoints(skinTone);
	return SPRITE_SHEET_NAMES[codepoint] ? codepoint : 'default';
};

export const getSpriteSheetPath = (skinTone?: string, options?: SpriteSheetOptions): string => {
	const key = getSpriteSheetKey(skinTone);
	const name = SPRITE_SHEET_NAMES[key];
	return buildVersionedSpriteUrl(options?.retina ? `${name}@2x.png` : `${name}.png`);
};

let supportsImageSetCache: boolean | null = null;

const supportsImageSet = (): boolean => {
	if (supportsImageSetCache !== null) {
		return supportsImageSetCache;
	}

	if (!window.CSS?.supports) {
		return false;
	}

	supportsImageSetCache = window.CSS.supports(
		'background-image',
		"image-set(url('data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEA') 1x)",
	);
	return supportsImageSetCache;
};

export const getSpriteSheetBackground = (skinTone?: string): string => {
	const basePath = getSpriteSheetPath(skinTone);

	if (supportsImageSet()) {
		const retinaPath = getSpriteSheetPath(skinTone, {retina: true});
		return `image-set(url(${basePath}) 1x, url(${retinaPath}) 2x)`;
	}

	return `url(${basePath})`;
};
