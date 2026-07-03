/**
 * Shared image upload helpers.
 * Converts selected images to compressed JPEGs before sending them to storage.
 */

const MANAGED_IMAGE_BUCKET = 'Talents_Items';
const MAX_IMAGE_UPLOAD_INPUT_BYTES = 20 * 1024 * 1024;
const DEFAULT_COMPRESSED_IMAGE_TYPE = 'image/jpeg';
const DEFAULT_COMPRESSED_IMAGE_EXT = 'jpg';

function _imageUploadLog(level, action, details) {
  try {
    if (level === 'error' && typeof logError === 'function') return logError(action, details);
    if (level === 'warn' && typeof logWarn === 'function') return logWarn(action, details);
    if (typeof logInfo === 'function') return logInfo(action, details);
  } catch (e) {
    console.warn('[image-upload] log skipped:', e);
  }
  return Promise.resolve();
}

function _imageUploadFormatBytes(bytes) {
  const n = Number(bytes) || 0;
  if (n >= 1024 * 1024) return (n / 1024 / 1024).toFixed(1) + 'MB';
  return (n / 1024).toFixed(1) + 'KB';
}

function _imageUploadObjectUrl(file) {
  return new Promise((resolve, reject) => {
    const objectUrl = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => resolve({ img, objectUrl });
    img.onerror = () => {
      URL.revokeObjectURL(objectUrl);
      reject(new Error('이미지 파일을 읽지 못했습니다.'));
    };
    img.src = objectUrl;
  });
}

function _imageUploadCanvasBlob(canvas, mimeType, quality) {
  return new Promise(resolve => canvas.toBlob(resolve, mimeType, quality));
}

function _imageUploadFileFromBlob(blob, fileName) {
  try {
    return new File([blob], fileName, { type: blob.type || DEFAULT_COMPRESSED_IMAGE_TYPE });
  } catch (e) {
    blob.name = fileName;
    return blob;
  }
}

function _imageUploadSafePrefix(prefix) {
  return String(prefix || 'image').toLowerCase().replace(/[^a-z0-9_-]+/g, '_').replace(/^_+|_+$/g, '') || 'image';
}

function _imageUploadSafePart(value, fallback = 'unlinked') {
  const cleaned = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '_')
    .replace(/^_+|_+$/g, '');
  return cleaned || fallback;
}

function _imageUploadTimestamp(date = new Date()) {
  const pad = n => String(n).padStart(2, '0');
  return [
    date.getFullYear(),
    pad(date.getMonth() + 1),
    pad(date.getDate()),
    pad(date.getHours()),
    pad(date.getMinutes()),
    pad(date.getSeconds())
  ].join('');
}

function buildManagedImageFileName(options = {}) {
  const folder = _imageUploadSafePrefix(options.folder || options.prefix || options.context || 'image');
  const prefix = _imageUploadSafePrefix(options.prefix || options.context || 'image');
  const entityId = _imageUploadSafePart(options.entityId || options.id);
  const linkedId = options.linkedId ? `_ref_${_imageUploadSafePart(options.linkedId)}` : '';
  const stamp = options.timestamp || _imageUploadTimestamp();
  const random = Math.random().toString(36).slice(2, 8);
  const ext = _imageUploadSafePart(options.ext || DEFAULT_COMPRESSED_IMAGE_EXT, DEFAULT_COMPRESSED_IMAGE_EXT);
  return `${folder}/${prefix}_${entityId}${linkedId}_${stamp}_${random}.${ext}`;
}

async function compressImageFile(file, options = {}) {
  if (!file) return { file: null, error: '이미지 파일을 선택해주세요.' };
  if (!String(file.type || '').startsWith('image/')) return { file: null, error: '이미지 파일만 업로드할 수 있습니다.' };

  const maxInputBytes = options.maxInputBytes || MAX_IMAGE_UPLOAD_INPUT_BYTES;
  if (file.size > maxInputBytes) {
    return { file: null, error: `${_imageUploadFormatBytes(maxInputBytes)} 이하 이미지 파일만 업로드할 수 있습니다.` };
  }

  let objectUrl = null;
  try {
    const loaded = await _imageUploadObjectUrl(file);
    const img = loaded.img;
    objectUrl = loaded.objectUrl;

    const maxWidth = options.maxWidth || 1280;
    const maxHeight = options.maxHeight || 1280;
    const quality = options.quality || 0.82;
    const mimeType = options.mimeType || DEFAULT_COMPRESSED_IMAGE_TYPE;
    const originalWidth = img.naturalWidth || img.width;
    const originalHeight = img.naturalHeight || img.height;
    const ratio = Math.min(maxWidth / originalWidth, maxHeight / originalHeight, 1);
    const width = Math.max(1, Math.round(originalWidth * ratio));
    const height = Math.max(1, Math.round(originalHeight * ratio));

    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext('2d', { alpha: false });
    if (!ctx) return { file: null, error: '이미지 압축을 지원하지 않는 브라우저입니다.' };

    ctx.fillStyle = options.background || '#ffffff';
    ctx.fillRect(0, 0, width, height);
    ctx.drawImage(img, 0, 0, width, height);

    const blob = await _imageUploadCanvasBlob(canvas, mimeType, quality);
    if (!blob) return { file: null, error: '이미지를 압축하지 못했습니다.' };

    const baseName = String(file.name || 'image').replace(/\.[^.]+$/, '') || 'image';
    const compressedName = `${baseName}.${DEFAULT_COMPRESSED_IMAGE_EXT}`;
    return {
      file: _imageUploadFileFromBlob(blob, compressedName),
      error: null,
      originalSize: file.size,
      compressedSize: blob.size,
      originalWidth,
      originalHeight,
      width,
      height,
      mimeType
    };
  } catch (err) {
    return { file: null, error: err.message || String(err) };
  } finally {
    if (objectUrl) URL.revokeObjectURL(objectUrl);
  }
}

async function uploadManagedImage(file, options = {}) {
  if (!_sb) return { url: null, error: 'Supabase not initialized' };

  const context = options.context || 'image';
  const compressed = await compressImageFile(file, options);
  if (compressed.error) {
    await _imageUploadLog('error', 'IMAGE_COMPRESS_FAIL', { 구분: context, 오류: compressed.error });
    return { url: null, error: compressed.error };
  }

  try {
    const bucket = options.bucket || MANAGED_IMAGE_BUCKET;
    const fileName = buildManagedImageFileName(Object.assign({}, options, { ext: DEFAULT_COMPRESSED_IMAGE_EXT }));
    const uploadFile = compressed.file;
    const { data, error } = await _sb.storage.from(bucket).upload(fileName, uploadFile, {
      cacheControl: options.cacheControl || '3600',
      upsert: false,
      contentType: uploadFile.type || compressed.mimeType || DEFAULT_COMPRESSED_IMAGE_TYPE
    });
    if (error) {
      await _imageUploadLog('error', 'IMAGE_UPLOAD_FAIL', { 구분: context, 오류: error.message });
      return { url: null, error: error.message };
    }

    const { data: urlData } = _sb.storage.from(bucket).getPublicUrl(data.path);
    await _imageUploadLog('info', 'IMAGE_UPLOAD', {
      구분: context,
      path: data.path,
      파일명: fileName,
      원본크기: compressed.originalSize,
      업로드크기: compressed.compressedSize,
      원본해상도: `${compressed.originalWidth}x${compressed.originalHeight}`,
      업로드해상도: `${compressed.width}x${compressed.height}`
    });
    return {
      url: urlData.publicUrl,
      error: null,
      path: data.path,
      fileName,
      originalSize: compressed.originalSize,
      uploadedSize: compressed.compressedSize
    };
  } catch (err) {
    await _imageUploadLog('error', 'IMAGE_UPLOAD_ERROR', { 구분: context, 오류: String(err) });
    return { url: null, error: String(err) };
  }
}
