import fs from 'node:fs/promises';
import path from 'node:path';
import { parse } from 'csv-parse';

export async function ensureDir(dirPath) {
  await fs.mkdir(dirPath, { recursive: true });
}

export async function fileExists(p) {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

export async function readJson(jsonPath) {
  const buf = await fs.readFile(jsonPath, 'utf8');
  return JSON.parse(buf);
}

export async function writeJson(jsonPath, data) {
  const dir = path.dirname(jsonPath);
  await ensureDir(dir);
  await fs.writeFile(jsonPath, JSON.stringify(data, null, 2), 'utf8');
}

export async function readCsv(csvPath, options = {}) {
  const content = await fs.readFile(csvPath, 'utf8');
  const delimiter = options.delimiter ?? ',';
  const columns = options.columns ?? true;
  return new Promise((resolve, reject) => {
    parse(content, { delimiter, columns, skip_empty_lines: true, trim: true }, (err, records) => {
      if (err) return reject(err);
      resolve(records);
    });
  });
}

export function groupBy(array, keyFn) {
  const map = new Map();
  for (const item of array) {
    const key = keyFn(item);
    const bucket = map.get(key) ?? [];
    bucket.push(item);
    map.set(key, bucket);
  }
  return map;
}


