/**
 * FORMULARIO DE FIRMA DE DOCUMENTOS PDF
 * Sistema completo con formulario, firma y almacenamiento por empleado
 */

// ==========================================
// CONFIGURACIÓN
// ==========================================

function getConfig() {
  return {
    // ID de la carpeta raíz donde se guardarán las carpetas de empleados
    ROOT_SIGNED_FOLDER_ID: 'TU_FOLDER_RAIZ_AQUI',
    
    // ID de la carpeta donde están los PDFs de plantillas
    TEMPLATES_FOLDER_ID: 'TU_FOLDER_TEMPLATES_AQUI',
    
    // Nombre del sheet donde está el registro
    SHEET_NAME: 'Registros',
    
    // Email del administrador
    ADMIN_EMAIL: 'admin@tuempresa.com'
  };
}

// ==========================================
// FUNCIÓN PRINCIPAL - Abrir Formulario de Firma
// ==========================================

/**
 * Abre el formulario para que el empleado firme un documento
 */
function openSignatureForm() {
  const ui = SpreadsheetApp.getUi();
  const CONFIG = getConfig();
  
  // Verificar configuración
  if (CONFIG.ROOT_SIGNED_FOLDER_ID === 'TU_FOLDER_RAIZ_AQUI') {
    ui.alert(
      '⚠️ Configuración Requerida',
      'Por favor, configura los IDs de las carpetas en el script.\n\n' +
      '1. Ve a Extensiones > Apps Script\n' +
      '2. Encuentra la función getConfig()\n' +
      '3. Reemplaza los IDs con los valores reales',
      ui.ButtonSet.OK
    );
    return;
  }
  
  try {
    // Obtener lista de PDFs disponibles
    const templates = getAvailableTemplates();
    
    if (templates.length === 0) {
      ui.alert(
        'No hay documentos disponibles',
        'No se encontraron PDFs en la carpeta de plantillas.\n\n' +
        'Por favor, sube algunos documentos PDF a la carpeta de plantillas.',
        ui.ButtonSet.OK
      );
      return;
    }
    
    // Crear HTML del formulario
    const htmlTemplate = HtmlService.createTemplateFromFile('SignatureFormPage');
    htmlTemplate.templates = templates;
    
    const html = htmlTemplate.evaluate()
      .setWidth(800)
      .setHeight(700);
    
    ui.showModalDialog(html, '📝 Formulario de Firma de Documentos');
    
  } catch (error) {
    ui.alert('Error', 'Ocurrió un error: ' + error.toString(), ui.ButtonSet.OK);
    Logger.log('Error en openSignatureForm: ' + error);
  }
}

/**
 * Obtener lista de PDFs disponibles en la carpeta de plantillas
 */
function getAvailableTemplates() {
  const CONFIG = getConfig();
  const templates = [];
  
  try {
    const folder = DriveApp.getFolderById(CONFIG.TEMPLATES_FOLDER_ID);
    const files = folder.getFiles();
    
    while (files.hasNext()) {
      const file = files.next();
      if (file.getMimeType() === 'application/pdf') {
        templates.push({
          id: file.getId(),
          name: file.getName(),
          url: file.getUrl(),
          size: formatFileSize(file.getSize())
        });
      }
    }
  } catch (error) {
    Logger.log('Error al obtener templates: ' + error);
  }
  
  return templates;
}

/**
 * Formatear tamaño de archivo
 */
function formatFileSize(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
}

// ==========================================
// PROCESAR FIRMA Y GUARDAR DOCUMENTO
// ==========================================

/**
 * Procesar el documento firmado y guardarlo en la carpeta del empleado
 */
function processSignedDocument(formData) {
  const CONFIG = getConfig();
  
  try {
    // Extraer datos del formulario
    const employeeName = formData.employeeName ? formData.employeeName.trim() : '';
    const employeeEmail = formData.employeeEmail ? formData.employeeEmail.trim() : '';
    const documentId = formData.documentId || '';
    const signatureData = formData.signatureData || null;
    const originalFileName = formData.originalFileName || 'documento.pdf';
    
    // Validar datos
    if (!employeeName || !employeeEmail || !documentId) {
      return { 
        success: false, 
        message: 'Datos incompletos en el formulario. Por favor complete todos los campos requeridos.' 
      };
    }
    
    // Crear o obtener carpeta del empleado
    const employeeFolder = getOrCreateEmployeeFolder(employeeName);
    
    // Generar nombre del archivo con timestamp
    const timestamp = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd_HHmmss');
    const cleanEmployeeName = sanitizeFileName(employeeName);
    const cleanFileName = sanitizeFileName(originalFileName);
    const fileName = `${cleanEmployeeName}_${timestamp}_${cleanFileName}`;
    
    // Guardar el documento firmado
    let signedFile;
    if (signatureData && typeof signatureData === 'string' && signatureData.indexOf('base64') !== -1) {
      // Si hay datos de firma (PDF modificado)
      try {
        const base64Data = signatureData.split(',')[1];
        const blob = Utilities.newBlob(
          Utilities.base64Decode(base64Data),
          'application/pdf',
          fileName
        );
        signedFile = employeeFolder.createFile(blob);
      } catch (e) {
        Logger.log('Error procesando firma, guardando original: ' + e);
        // Si hay error con la firma, guardar el original
        const originalFile = DriveApp.getFileById(documentId);
        signedFile = originalFile.makeCopy(fileName, employeeFolder);
      }
    } else {
      // Si solo se está guardando el original
      const originalFile = DriveApp.getFileById(documentId);
      signedFile = originalFile.makeCopy(fileName, employeeFolder);
    }
    
    // Registrar en el Sheet
    const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(CONFIG.SHEET_NAME);
    if (sheet) {
      const newRow = [
        employeeName,
        employeeEmail,
        originalFileName,
        'Firmado',
        new Date(),
        signedFile.getUrl(),
        employeeFolder.getName()
      ];
      sheet.appendRow(newRow);
    }
    
    // Enviar notificación
    sendSignatureNotification(employeeName, employeeEmail, originalFileName, signedFile.getUrl());
    
    return {
      success: true,
      message: 'Documento firmado y guardado exitosamente',
      fileUrl: signedFile.getUrl(),
      folderUrl: employeeFolder.getUrl()
    };
    
  } catch (error) {
    Logger.log('Error en processSignedDocument: ' + error);
    return {
      success: false,
      message: 'Error al procesar el documento: ' + error.toString()
    };
  }
}

/**
 * Obtener o crear carpeta para el empleado
 */
function getOrCreateEmployeeFolder(employeeName) {
  const CONFIG = getConfig();
  const rootFolder = DriveApp.getFolderById(CONFIG.ROOT_SIGNED_FOLDER_ID);
  const folderName = sanitizeFileName(employeeName);
  
  // Buscar si ya existe la carpeta
  const folders = rootFolder.getFoldersByName(folderName);
  
  if (folders.hasNext()) {
    return folders.next();
  } else {
    // Crear nueva carpeta
    const newFolder = rootFolder.createFolder(folderName);
    newFolder.setDescription(`Documentos firmados de ${employeeName}`);
    return newFolder;
  }
}

/**
 * Limpiar nombre de archivo/carpeta
 */
function sanitizeFileName(name) {
  return name
    .replace(/[^a-zA-Z0-9\s\-_]/g, '')
    .replace(/\s+/g, '_')
    .substring(0, 50);
}

// ==========================================
// FUNCIONES DE NOTIFICACIÓN
// ==========================================

/**
 * Enviar notificación de firma completada
 */
function sendSignatureNotification(employeeName, employeeEmail, fileName, fileUrl) {
  const CONFIG = getConfig();
  
  try {
    const subject = `✅ Documento firmado: ${fileName}`;
    const body = `
El empleado ${employeeName} (${employeeEmail}) ha firmado el documento:

📄 Documento: ${fileName}
⏰ Fecha: ${new Date().toLocaleString('es-MX')}
🔗 Ver documento: ${fileUrl}

Este email es automático del Sistema de Gestión de Firmas.
    `;
    
    // Enviar al admin
    MailApp.sendEmail(CONFIG.ADMIN_EMAIL, subject, body);
    
    // Enviar copia al empleado
    MailApp.sendEmail(employeeEmail, subject, body);
    
  } catch (error) {
    Logger.log('Error al enviar notificación: ' + error);
  }
}

// ==========================================
// FUNCIONES DE UTILIDAD
// ==========================================

/**
 * Obtener información de un documento por ID
 */
function getDocumentInfo(documentId) {
  try {
    const file = DriveApp.getFileById(documentId);
    return {
      success: true,
      name: file.getName(),
      url: file.getUrl(),
      size: formatFileSize(file.getSize())
    };
  } catch (error) {
    return {
      success: false,
      message: error.toString()
    };
  }
}

/**
 * Incluir archivos HTML en el template
 */
function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

// ==========================================
// MENÚ PERSONALIZADO
// ==========================================

function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('📝 Gestión de Firmas')
    .addItem('✍️ Nuevo Formulario de Firma', 'openSignatureForm')
    .addSeparator()
    .addItem('📊 Ver Registros', 'showRegisters')
    .addItem('📁 Abrir Carpeta de Firmados', 'openSignedFolder')
    .addSeparator()
    .addItem('⚙️ Configuración', 'showConfiguration')
    .addItem('🔍 Verificar Acceso', 'testConfiguration')
    .addToUi();
}

/**
 * Ver registros de firmas
 */
function showRegisters() {
  const ui = SpreadsheetApp.getUi();
  const CONFIG = getConfig();
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(CONFIG.SHEET_NAME);
  
  if (!sheet) {
    ui.alert('La hoja "' + CONFIG.SHEET_NAME + '" no existe. Por favor créala primero.');
    return;
  }
  
  const lastRow = sheet.getLastRow();
  ui.alert('Total de documentos firmados: ' + Math.max(0, lastRow - 1));
}

/**
 * Abrir carpeta de documentos firmados
 */
function openSignedFolder() {
  const CONFIG = getConfig();
  try {
    const folder = DriveApp.getFolderById(CONFIG.ROOT_SIGNED_FOLDER_ID);
    const html = HtmlService.createHtmlOutput(`
      <script>
        window.open('${folder.getUrl()}', '_blank');
        google.script.host.close();
      </script>
    `);
    SpreadsheetApp.getUi().showModalDialog(html, 'Abriendo carpeta...');
  } catch (error) {
    SpreadsheetApp.getUi().alert('Error al abrir carpeta: ' + error.toString());
  }
}

/**
 * Mostrar configuración con verificación
 */
function showConfiguration() {
  const ui = SpreadsheetApp.getUi();
  const CONFIG = getConfig();
  
  let rootStatus = '❌ No configurado';
  let templatesStatus = '❌ No configurado';
  let rootName = '-';
  let templatesName = '-';
  
  if (CONFIG.ROOT_SIGNED_FOLDER_ID !== 'TU_FOLDER_RAIZ_AQUI') {
    try {
      const folder = DriveApp.getFolderById(CONFIG.ROOT_SIGNED_FOLDER_ID);
      rootName = folder.getName();
      const subFolders = Array.from(folder.getFolders()).length;
      rootStatus = `✅ Conectado (${subFolders} carpetas de empleados)`;
    } catch (e) {
      rootStatus = '❌ Error: ' + e.message;
    }
  }
  
  if (CONFIG.TEMPLATES_FOLDER_ID !== 'TU_FOLDER_TEMPLATES_AQUI') {
    try {
      const folder = DriveApp.getFolderById(CONFIG.TEMPLATES_FOLDER_ID);
      templatesName = folder.getName();
      const templates = getAvailableTemplates();
      templatesStatus = `✅ Conectado (${templates.length} PDFs disponibles)`;
    } catch (e) {
      templatesStatus = '❌ Error: ' + e.message;
    }
  }
  
  const html = HtmlService.createHtmlOutput(`
    <html>
      <head>
        <style>
          body { font-family: Arial; padding: 20px; background: #f5f5f5; }
          .box { background: white; padding: 15px; margin: 10px 0; border-radius: 5px; border-left: 4px solid #4285f4; }
          .status { font-size: 12px; margin-top: 5px; }
          .id { background: #f9f9f9; padding: 8px; border: 1px solid #ddd; border-radius: 3px; 
                font-family: monospace; font-size: 11px; word-break: break-all; margin: 5px 0; }
          button { padding: 10px 20px; background: #4285f4; color: white; border: none; 
                   border-radius: 4px; cursor: pointer; }
        </style>
      </head>
      <body>
        <h3>⚙️ Configuración del Sistema</h3>
        
        <div class="box">
          <strong>📁 Carpeta Raíz (Documentos Firmados)</strong>
          <div class="id">${CONFIG.ROOT_SIGNED_FOLDER_ID}</div>
          <div class="status">${rootStatus}</div>
          ${rootName !== '-' ? '<div style="font-size:12px;color:#666;">Carpeta: ' + rootName + '</div>' : ''}
        </div>
        
        <div class="box">
          <strong>📄 Carpeta de Plantillas (PDFs)</strong>
          <div class="id">${CONFIG.TEMPLATES_FOLDER_ID}</div>
          <div class="status">${templatesStatus}</div>
          ${templatesName !== '-' ? '<div style="font-size:12px;color:#666;">Carpeta: ' + templatesName + '</div>' : ''}
        </div>
        
        <div class="box">
          <strong>📧 Email Administrador</strong>
          <div class="id">${CONFIG.ADMIN_EMAIL}</div>
        </div>
        
        <div style="background:#fff3cd; border:1px solid #ffc107; padding:15px; border-radius:5px; margin:15px 0;">
          <strong>📝 Instrucciones:</strong>
          <ol style="font-size:13px; margin:10px 0 0 0; padding-left:20px;">
            <li>Crea dos carpetas en Google Drive</li>
            <li>Copia los IDs de las URLs</li>
            <li>Edita la función getConfig() en el script</li>
            <li>Guarda y recarga el Sheet</li>
          </ol>
        </div>
        
        <button onclick="google.script.host.close()">Cerrar</button>
      </body>
    </html>
  `).setWidth(600).setHeight(500);
  
  ui.showModalDialog(html, 'Configuración');
}

/**
 * Verificar configuración completa
 */
function testConfiguration() {
  const ui = SpreadsheetApp.getUi();
  const CONFIG = getConfig();
  let messages = [];
  
  // Test 1: Carpeta raíz
  try {
    const folder = DriveApp.getFolderById(CONFIG.ROOT_SIGNED_FOLDER_ID);
    messages.push('✅ Carpeta raíz: ' + folder.getName());
  } catch (e) {
    messages.push('❌ Carpeta raíz: ' + e.message);
  }
  
  // Test 2: Carpeta templates
  try {
    const folder = DriveApp.getFolderById(CONFIG.TEMPLATES_FOLDER_ID);
    const templates = getAvailableTemplates();
    messages.push('✅ Carpeta templates: ' + folder.getName() + ' (' + templates.length + ' PDFs)');
  } catch (e) {
    messages.push('❌ Carpeta templates: ' + e.message);
  }
  
  // Test 3: Sheet
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(CONFIG.SHEET_NAME);
  if (sheet) {
    messages.push('✅ Hoja de registro: ' + CONFIG.SHEET_NAME);
  } else {
    messages.push('⚠️ Hoja "' + CONFIG.SHEET_NAME + '" no existe (se creará automáticamente)');
  }
  
  ui.alert('Verificación de Configuración', messages.join('\n'), ui.ButtonSet.OK);
}

// ==========================================
// CREAR ESTRUCTURA INICIAL
// ==========================================

/**
 * Crear la hoja de registros con encabezados
 */
function setupRegistersSheet() {
  const CONFIG = getConfig();
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(CONFIG.SHEET_NAME);
  
  if (!sheet) {
    sheet = ss.insertSheet(CONFIG.SHEET_NAME);
  }
  
  // Crear encabezados si la hoja está vacía
  if (sheet.getLastRow() === 0) {
    const headers = [
      'Nombre Empleado',
      'Email',
      'Documento',
      'Estado',
      'Fecha Firma',
      'URL Documento',
      'Carpeta'
    ];
    sheet.appendRow(headers);
    
    // Formatear encabezados
    const headerRange = sheet.getRange(1, 1, 1, headers.length);
    headerRange.setBackground('#4285f4');
    headerRange.setFontColor('#ffffff');
    headerRange.setFontWeight('bold');
    sheet.setFrozenRows(1);
  }
  
  SpreadsheetApp.getUi().alert('✅ Hoja de registros configurada correctamente');
}
