## Working with uploaded images
If you need to use uploaded images by hash, you MUST use the `@app/storage` library
<example>
import { getThumbnailUrl } from "@app/storage"

<img src={getThumbnailUrl(imageHash, 300, 500)} /> // Returns an image sized 300x500
<img src={getThumbnailUrl(imageHash, 300, undefined)} /> // Returns an image with width 300 and proportional height
<img src={getThumbnailUrl(imageHash, undefined, 500)} /> // Returns an image with height 500 and proportional width
</example>
Display the image by hash using `getThumbnailUrl` with width and height parameters appropriate to the context. Account for Retina displays.

## Chatium file service URLs

Files are hosted on `fs.chatium.ru`. URL patterns:

- **Full file**: `https://fs.chatium.ru/get/<hash>`
  Example: `https://fs.chatium.ru/get/image_msk_Aq6e10pWWI.1280x958.jpeg`

- **Thumbnail with width**: `https://fs.chatium.ru/thumbnail/<hash>/s/<width>x`
  Example: `https://fs.chatium.ru/thumbnail/image_msk_Aq6e10pWWI.1280x958.jpeg/s/800x`

- **Thumbnail with exact size**: `https://fs.chatium.ru/thumbnail/<hash>/s/<width>x<height>`
  Example: `https://fs.chatium.ru/thumbnail/image_msk_Aq6e10pWWI.1280x958.jpeg/s/800x600`

## Uploading static files (images, binaries)

To upload a file to the Chatium file service and get its hash:
```bash
${SKILL_DIR}/chatium-sync.sh upload-static <path-to-file>
```

This uploads the file via multipart/form-data to the file service and returns:
- The file hash (e.g., `image_msk_Aq6e10pWWI.1280x958.jpeg`)
- Full URL, thumbnail URLs
- Code example with `getThumbnailUrl`

### Workflow: local images → Chatium code
1. Upload each image: `chatium-sync.sh upload-static assets/logo.png`
2. Get the hash from output
3. Use in code: `getThumbnailUrl("image_msk_...", 800, undefined)`

## Working with image and file uploads

If you need to upload a file or image, look for an example of how it is done.
