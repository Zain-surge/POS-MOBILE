// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_order.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineOrderAdapter extends TypeAdapter<OfflineOrder> {
  @override
  final int typeId = 0;

  @override
  OfflineOrder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineOrder(
      localId: fields[0] as String,
      transactionId: fields[1] as String,
      paymentType: fields[2] as String,
      orderType: fields[3] as String,
      orderTotalPrice: fields[4] as double,
      orderExtraNotes: fields[5] as String?,
      customerName: fields[6] as String,
      customerEmail: fields[7] as String?,
      phoneNumber: fields[8] as String?,
      streetAddress: fields[9] as String?,
      city: fields[10] as String?,
      postalCode: fields[11] as String?,
      changeDue: fields[12] as double,
      items: (fields[13] as List).cast<OfflineCartItem>(),
      createdAt: fields[14] as DateTime,
      status: fields[15] as String,
      syncAttempts: fields[16] as int?,
      syncError: fields[17] as String?,
      serverId: fields[18] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineOrder obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.localId)
      ..writeByte(1)
      ..write(obj.transactionId)
      ..writeByte(2)
      ..write(obj.paymentType)
      ..writeByte(3)
      ..write(obj.orderType)
      ..writeByte(4)
      ..write(obj.orderTotalPrice)
      ..writeByte(5)
      ..write(obj.orderExtraNotes)
      ..writeByte(6)
      ..write(obj.customerName)
      ..writeByte(7)
      ..write(obj.customerEmail)
      ..writeByte(8)
      ..write(obj.phoneNumber)
      ..writeByte(9)
      ..write(obj.streetAddress)
      ..writeByte(10)
      ..write(obj.city)
      ..writeByte(11)
      ..write(obj.postalCode)
      ..writeByte(12)
      ..write(obj.changeDue)
      ..writeByte(13)
      ..write(obj.items)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.status)
      ..writeByte(16)
      ..write(obj.syncAttempts)
      ..writeByte(17)
      ..write(obj.syncError)
      ..writeByte(18)
      ..write(obj.serverId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineOrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineCartItemAdapter extends TypeAdapter<OfflineCartItem> {
  @override
  final int typeId = 1;

  @override
  OfflineCartItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineCartItem(
      foodItem: fields[0] as OfflineFoodItem,
      quantity: fields[1] as int,
      selectedOptions: (fields[2] as List?)?.cast<String>(),
      comment: fields[3] as String?,
      pricePerUnit: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineCartItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.foodItem)
      ..writeByte(1)
      ..write(obj.quantity)
      ..writeByte(2)
      ..write(obj.selectedOptions)
      ..writeByte(3)
      ..write(obj.comment)
      ..writeByte(4)
      ..write(obj.pricePerUnit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineCartItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OfflineFoodItemAdapter extends TypeAdapter<OfflineFoodItem> {
  @override
  final int typeId = 2;

  @override
  OfflineFoodItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineFoodItem(
      id: fields[0] as int,
      name: fields[1] as String,
      category: fields[2] as String,
      price: (fields[3] as Map).cast<String, double>(),
      image: fields[4] as String,
      defaultToppings: (fields[5] as List?)?.cast<String>(),
      defaultCheese: (fields[6] as List?)?.cast<String>(),
      description: fields[7] as String?,
      subType: fields[8] as String?,
      sauces: (fields[9] as List?)?.cast<String>(),
      availability: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineFoodItem obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.image)
      ..writeByte(5)
      ..write(obj.defaultToppings)
      ..writeByte(6)
      ..write(obj.defaultCheese)
      ..writeByte(7)
      ..write(obj.description)
      ..writeByte(8)
      ..write(obj.subType)
      ..writeByte(9)
      ..write(obj.sauces)
      ..writeByte(10)
      ..write(obj.availability);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineFoodItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
