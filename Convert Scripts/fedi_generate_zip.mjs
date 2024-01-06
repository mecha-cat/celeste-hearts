import { spawnSync } from "node:child_process";
import { copyFile, mkdtemp, readFile, rm, rmdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, basename, extname, resolve } from "node:path";
import { createHash } from "node:crypto";

const __dirname = dirname(decodeURI(new URL(import.meta.url).pathname));

/** @type {string} */
const hearts = await readFile(resolve(__dirname, "misskey_hearts_list.txt"), "utf-8");

const extraAliases = {
	mlm: ["gay"],
	non_binary: ["nonbinary", "enby"]
}

/**
 * @typedef {
 *   {
 *     downloaded: boolean,
 *     fileName: string,
 *     emoji: {
 *       id?: string,
 *       updatedAt?: string,
 *       name: string,
 *       host?: string,
 *       category: string,
 *       originalUrl?: string,
 *       publicUrl?: string,
 *       uri?: string,
 *       type?: string,
 *       aliases: string[]
 *     }
 *   }
 * } Emoji
 */
/** @type {Emoji[]} */
const emojiMetas = [];

/** @type {Map<string, string>} */
const akkomaMetas = new Map();

const tempdir = await mkdtemp(resolve(tmpdir(), "celesteHeartsEmoji"));
console.debug(`Temporary directory is ${tempdir}`);

for(const fileName of hearts.split("\n").filter(Boolean).filter(x => !x.startsWith("#"))){
	console.debug(`Processing ${fileName}`);
	try{
		const __name = basename(fileName, extname(fileName))
			.toLowerCase()
			.replace("celeste_hearts_", "")
			.replace("ch_", "")
			.replace(/\s\d+$/, "")
			.replace(" ", "_")
			.replace("-", "_");
		const newFileName = "celeste_hearts_" + __name + extname(fileName);

		await copyFile(resolve(__dirname, fileName), resolve(tempdir, newFileName));

		/** @type {Emoji} */
		const emojiMeta = {
			downloaded: true,
			fileName: newFileName,
			emoji: {
				name: "celeste_hearts_" + __name,
				category: "celeste_hearts",
				aliases: [
					"ch_" + __name,
					...(extraAliases[__name]?.map(x => "celeste_hearts_" + x) || []),
					...(extraAliases[__name]?.map(x => "ch_" + x) || [])
				]
			}
		}

		emojiMetas.push(emojiMeta);
		akkomaMetas.set("celeste_hearts_" + __name, newFileName);
	}catch(_){
		console.error(`Cannot access file ${fileName}. Does it exist? Do you have permissions for it?`);
	}
}

/**
 * @typedef {
 *   {
 *     metaVersion: number,
 *     host: string,
 *     exportedAt: string,
 *     emojis: Emoji[]
 *   }
 * } Meta
 */
const meta = {
	metaVersion: 2,
	host: "cataclysm.systems",
	exportedAt: new Date().toISOString(),
	emojis: emojiMetas.sort((a, b) => a.fileName.localeCompare(b.fileName))
}

console.debug("Zipping for Mastodon Admin Console");
spawnSync("tar", ["-cvf", resolve(__dirname, "..", "celeste_hearts_mastodon_emojis.tar.gz"), "-C", tempdir, "."], { stdio: "pipe" });

console.debug("Generating Misskey meta.json");
await writeFile(resolve(tempdir, "meta.json"), JSON.stringify(meta, undefined, 2), "utf8");

console.debug("Zipping for Misskey");
spawnSync("zip", ["-rj", resolve(__dirname, "..", "celeste_hearts_misskey_emojis.zip"), tempdir], { stdio: "pipe" });

console.debug("Generating Akkoma/Pleroma manifest and reference files");
const manifest = {
  "celeste_hearts": {
    "description": "Pride hearts encased in hearts, inspired by the Celeste game.",
    "files": "celeste_hearts_akkoma.json",
    "homepage": "https://github.com/mecha-cat/celeste-hearts/",
    "src": "https://github.com/mecha-cat/celeste-hearts/raw/main/celeste_hearts_misskey_emojis.zip",
    "src_sha256": createHash("sha256").update(await readFile(resolve(__dirname, "..", "celeste_hearts_misskey_emojis.zip"))).digest("hex"),
    "license": "CC BY-NC-SA 4.0"
  }
}
await writeFile(resolve(__dirname, "..", "celeste_hearts_akkoma.json"), JSON.stringify(Object.fromEntries(akkomaMetas), undefined, 2), "utf8");
await writeFile(resolve(__dirname, "..", "celeste_hearts_akkoma_manifest.json"), JSON.stringify(manifest, undefined, 2), "utf8");


console.debug("Removing temporary directory");
await rm(tempdir, {recursive: true});
