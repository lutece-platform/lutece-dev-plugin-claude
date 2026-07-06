# File Upload Migration — Lutece v8

## Overview

Apache Commons FileUpload is replaced by the Servlet API. `FileItem` becomes `MultipartItem`.

## Import Changes

| v7 | v8 |
|----|-----|
| `org.apache.commons.fileupload.FileItem` | `fr.paris.lutece.portal.service.upload.MultipartItem` |
| `org.apache.commons.fileupload.FileUploadException` | (no longer needed) |
| `org.apache.commons.fileupload2.core.FileItem` | `fr.paris.lutece.portal.service.upload.MultipartItem` |

## Basic File Upload

### Before (v7)
```java
MultipartHttpServletRequest multipartRequest = (MultipartHttpServletRequest) request;
FileItem fileItem = multipartRequest.getFile("file_upload");
if (fileItem != null && fileItem.getSize() > 0) {
    String fileName = fileItem.getName();
    byte[] content = fileItem.get();
}
```

### After (v8)
```java
MultipartHttpServletRequest multipartRequest = (MultipartHttpServletRequest) request;
MultipartItem multipartItem = multipartRequest.getFile("file_upload");
if (multipartItem != null && multipartItem.getSize() > 0) {
    String fileName = multipartItem.getName();
    byte[] content = multipartItem.get();
}
```

## With MVC Annotations

```java
@Action(ACTION_UPLOAD)
public String doUpload(@RequestParam("file_upload") MultipartItem multipartItem) {
    if (multipartItem != null && multipartItem.getSize() > 0) {
        // process file
    }
    return redirectView(request, VIEW_LIST);
}
```

## Multiple Files

```java
@Action(ACTION_UPLOAD_MULTI)
public String doUploadMulti(HttpServletRequest request) {
    MultipartHttpServletRequest multipartRequest = (MultipartHttpServletRequest) request;
    List<MultipartItem> items = multipartRequest.getFileList("files");
    for (MultipartItem item : items) {
        // process each file
    }
    return redirectView(request, VIEW_LIST);
}
```

## Creating a MultipartItem in memory

When migrating code that used to create a `FileItem` from raw bytes (e.g. base64-decoded payloads, in-memory blobs) with `new DiskFileItemFactory().createItem(...)` + `getOutputStream().write(content)`, use **`MemoryFileItem`** from `library-httpaccess` — it is the v8 in-memory implementation of `MultipartItem`.

```java
import fr.paris.lutece.portal.service.upload.MultipartItem;
import fr.paris.lutece.util.httpaccess.MemoryFileItem;

private static MultipartItem createFileItem( String fileName, String contentType, byte[] content )
{
    return new MemoryFileItem( content, fileName, content.length, contentType );
}
```

Constructor: `MemoryFileItem(byte[] data, String name, long size, String contentType)`.

Requires `library-httpaccess` (v4+) in the project `pom.xml` — already present in most Lutece plugins that do file I/O.

For file-backed items (already-on-disk content), use the core `TemporaryFileMultipartItem(File, String submittedFileName, String contentType, String fieldName)` instead.

## JspBean File Access

For JspBean-based file access, the `AdminMultipartFilter` and `AdminMultipartServlet` handle multipart parsing.

## Async Upload

For asynchronous file upload, use the `UploadServlet` with `MultipartAsyncUploadHandler` qualifier.

```java
@Inject
@MultipartUploadHandler
private IAsyncUploadHandler _uploadHandler;
```

## Template (Back-Office)

```html
<@tform action="..." method="post" enctype="multipart/form-data">
    <@addFileBOInput name="file_upload" labelKey="#i18n{myplugin.label.file}" />
    <@addBOUploadedFilesBox name="file_upload" />
    <@button type="submit" color="primary" labelKey="#i18n{portal.util.labelValidate}" />
</@tform>
```

Note: `enctype="multipart/form-data"` is required on the form.
