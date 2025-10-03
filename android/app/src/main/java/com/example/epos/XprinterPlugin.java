package com.example.epos;

import android.content.Context;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import net.posprinter.IDeviceConnection;
import net.posprinter.POSConnect;
import net.posprinter.POSPrinter;

/**
 * XprinterPlugin handles communication between Flutter and Xprinter SDK
 * Updated to prevent auto-printing of stored headers/numbers
 */
public class XprinterPlugin implements FlutterPlugin, MethodCallHandler {
    private static final String TAG = "XprinterPlugin";
    private static final String CHANNEL = "xprinter_sdk";

    private MethodChannel channel;
    private Context context;
    private ExecutorService executor;
    private Handler mainHandler;

    // Xprinter SDK objects
    private IDeviceConnection usbConnection;
    private POSPrinter posPrinter;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
        context = flutterPluginBinding.getApplicationContext();
        executor = Executors.newSingleThreadExecutor();
        mainHandler = new Handler(Looper.getMainLooper());

        // Initialize POSConnect SDK
        POSConnect.init(context);
        Log.d(TAG, "Xprinter SDK initialized");
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "getUsbDevices":
                getUsbDevices(result);
                break;
            case "connectUsb":
                String devicePath = call.argument("devicePath");
                connectUsb(devicePath, result);
                break;
            case "disconnect":
                disconnect(result);
                break;
            case "printReceipt":
                String receiptData = call.argument("receiptData");
                printReceipt(receiptData, result);
                break;
            case "openCashBox":
                Integer pinNum = call.argument("pinNum");
                Integer onTime = call.argument("onTime");
                Integer offTime = call.argument("offTime");
                openCashBox(pinNum, onTime, offTime, result);
                break;
            case "printerStatus":
                printerStatus(result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void getUsbDevices(Result result) {
        executor.execute(() -> {
            try {
                List<String> devicePaths = POSConnect.getUsbDevices(context);
                
                List<Map<String, Object>> devices = new ArrayList<>();
                UsbManager usbManager = (UsbManager) context.getSystemService(Context.USB_SERVICE);
                
                if (usbManager != null) {
                    for (UsbDevice device : usbManager.getDeviceList().values()) {
                        Map<String, Object> deviceInfo = new HashMap<>();
                        deviceInfo.put("deviceName", device.getDeviceName());
                        deviceInfo.put("vendorId", device.getVendorId());
                        deviceInfo.put("productId", device.getProductId());
                        deviceInfo.put("manufacturerName", device.getManufacturerName());
                        deviceInfo.put("productName", device.getProductName());
                        devices.add(deviceInfo);
                    }
                }

                mainHandler.post(() -> result.success(devices));
            } catch (Exception e) {
                Log.e(TAG, "Error getting USB devices", e);
                mainHandler.post(() -> result.error("GET_USB_DEVICES_ERROR", e.getMessage(), null));
            }
        });
    }

    private void connectUsb(String devicePath, Result result) {
        executor.execute(() -> {
            try {
                // Disconnect any existing connection
                if (usbConnection != null) {
                    usbConnection.close();
                    usbConnection = null;
                    posPrinter = null;
                }

                // Create USB connection
                usbConnection = POSConnect.createDevice(POSConnect.DEVICE_TYPE_USB);
                
                // Connect synchronously
                boolean connected = usbConnection.connectSync(devicePath, (code, connectInfo, message) -> {
                    Log.d(TAG, "USB Connection callback - Code: " + code + ", Info: " + connectInfo + ", Message: " + message);
                });

                if (connected) {
                    posPrinter = new POSPrinter(usbConnection);
                    
                    // CRITICAL: Clear printer memory on connection to prevent auto-headers
                    clearPrinterMemory();
                    
                    Log.d(TAG, "USB printer connected and memory cleared successfully");
                    mainHandler.post(() -> result.success(true));
                } else {
                    Log.e(TAG, "Failed to connect USB printer");
                    mainHandler.post(() -> result.success(false));
                }
            } catch (Exception e) {
                Log.e(TAG, "Error connecting USB printer", e);
                mainHandler.post(() -> result.error("USB_CONNECT_ERROR", e.getMessage(), null));
            }
        });
    }

    /**
     * Comprehensive method to clear all printer memory and stored settings
     * This prevents auto-printing of stored headers, numbers, or logos
     */
    private void clearPrinterMemory() {
        try {
            if (posPrinter == null) return;

            Log.d(TAG, "Clearing printer memory using SDK initialization...");

            // Use the SDK's built-in initialization method
            // This properly sends ESC/POS commands without converting them to text
            posPrinter.initializePrinter();

            // Wait for initialization to complete
            Thread.sleep(200);

            Log.d(TAG, "Printer initialized successfully");

        } catch (Exception e) {
            Log.e(TAG, "Error clearing printer memory: " + e.getMessage(), e);
        }
    }

    private void disconnect(Result result) {
        executor.execute(() -> {
            try {
                if (usbConnection != null) {
                    usbConnection.closeSync();
                    usbConnection = null;
                    posPrinter = null;
                    Log.d(TAG, "USB printer disconnected");
                }
                mainHandler.post(() -> result.success(true));
            } catch (Exception e) {
                Log.e(TAG, "Error disconnecting printer", e);
                mainHandler.post(() -> result.error("DISCONNECT_ERROR", e.getMessage(), null));
            }
        });
    }

    /**
     * Process receipt text and convert **bold** markers to ESC/POS bold commands
     */
    private void processBoldMarkersAndPrint(String receiptData) throws Exception {
        if (posPrinter == null) return;

        String[] lines = receiptData.split("\n");

        for (String line : lines) {
            if (line.contains("**")) {
                // Line contains bold markers - process them
                StringBuilder processedLine = new StringBuilder();
                int i = 0;
                boolean inBold = false;

                while (i < line.length()) {
                    if (i <= line.length() - 2 && line.substring(i, i + 2).equals("**")) {
                        // Toggle bold on/off
                        if (!inBold) {
                            // Start bold
                            processedLine.append((char) 0x1B).append((char) 0x45).append((char) 0x01); // ESC E 1
                            inBold = true;
                        } else {
                            // End bold
                            processedLine.append((char) 0x1B).append((char) 0x45).append((char) 0x00); // ESC E 0
                            inBold = false;
                        }
                        i += 2; // Skip **
                    } else {
                        processedLine.append(line.charAt(i));
                        i++;
                    }
                }

                // Ensure bold is turned off at end of line
                if (inBold) {
                    processedLine.append((char) 0x1B).append((char) 0x45).append((char) 0x00);
                }

                posPrinter.printString(processedLine.toString() + "\n");
            } else {
                // No bold markers - print as is
                posPrinter.printString(line + "\n");
            }
        }
    }

    private void printReceipt(String receiptData, Result result) {
        executor.execute(() -> {
            try {
                if (posPrinter == null) {
                    mainHandler.post(() -> result.error("NOT_CONNECTED", "Printer not connected", null));
                    return;
                }

                Log.d(TAG, "Starting receipt print with proper initialization");

                // STEP 1: Initialize printer using SDK method (not string commands)
                // This prevents control codes from being printed as text
                posPrinter.initializePrinter();
                Thread.sleep(100);
                
                // STEP 2: Process and print receipt with bold formatting
                processBoldMarkersAndPrint(receiptData);
                
                // STEP 3: Feed and cut
                posPrinter.feedLine(3).cutPaper();

                Log.d(TAG, "Receipt printed successfully without auto-header");
                mainHandler.post(() -> result.success(true));
                
            } catch (Exception e) {
                Log.e(TAG, "Error printing receipt", e);
                
                // Fallback: Try simple print
                try {
                    Log.d(TAG, "Attempting fallback print...");
                    posPrinter.initializePrinter()
                             .printString(receiptData)
                             .feedLine(3)
                             .cutPaper();
                    mainHandler.post(() -> result.success(true));
                } catch (Exception fallbackException) {
                    Log.e(TAG, "Both main and fallback print failed", fallbackException);
                    mainHandler.post(() -> result.error("PRINT_ERROR", e.getMessage(), null));
                }
            }
        });
    }

    private void openCashBox(Integer pinNum, Integer onTime, Integer offTime, Result result) {
        executor.execute(() -> {
            try {
                if (posPrinter == null) {
                    mainHandler.post(() -> result.error("NOT_CONNECTED", "Printer not connected", null));
                    return;
                }

                int pin = pinNum != null ? pinNum : 0;
                int on = onTime != null ? onTime : 30;
                int off = offTime != null ? offTime : 255;

                posPrinter.openCashBox(pin, on, off);
                Log.d(TAG, "Cash box opened");
                mainHandler.post(() -> result.success(true));
            } catch (Exception e) {
                Log.e(TAG, "Error opening cash box", e);
                mainHandler.post(() -> result.error("CASH_BOX_ERROR", e.getMessage(), null));
            }
        });
    }

    private void printerStatus(Result result) {
        executor.execute(() -> {
            try {
                if (usbConnection == null) {
                    mainHandler.post(() -> result.error("NOT_CONNECTED", "Printer not connected", null));
                    return;
                }

                Map<String, Object> statusInfo = new HashMap<>();
                statusInfo.put("connected", usbConnection != null);
                statusInfo.put("statusCode", usbConnection != null ? 1 : 0);
                mainHandler.post(() -> result.success(statusInfo));
            } catch (Exception e) {
                Log.e(TAG, "Error checking printer status", e);
                mainHandler.post(() -> result.error("STATUS_ERROR", e.getMessage(), null));
            }
        });
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        
        if (executor != null) {
            executor.shutdown();
        }
        
        if (usbConnection != null) {
            try {
                usbConnection.close();
            } catch (Exception e) {
                Log.e(TAG, "Error closing connection on detach", e);
            }
        }
        
        POSConnect.exit();
        Log.d(TAG, "Xprinter SDK plugin detached");
    }
}