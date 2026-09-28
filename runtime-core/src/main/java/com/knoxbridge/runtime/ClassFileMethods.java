package com.knoxbridge.runtime;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.util.ArrayList;
import java.util.List;

/** Minimal class-file reader used only to fail closed on missing/overloaded patch targets. */
final class ClassFileMethods {
    static List<String> descriptors(byte[] bytes, String wantedName) throws Exception {
        try (var in = new DataInputStream(new ByteArrayInputStream(bytes))) {
            if (in.readInt() != 0xCAFEBABE) throw new IllegalArgumentException("not a class file");
            in.readUnsignedShort(); in.readUnsignedShort();
            int count = in.readUnsignedShort();
            String[] utf = new String[count];
            for (int i = 1; i < count; i++) {
                int tag = in.readUnsignedByte();
                switch (tag) {
                    case 1 -> utf[i] = in.readUTF();
                    case 3, 4 -> in.skipNBytes(4);
                    case 5, 6 -> { in.skipNBytes(8); i++; }
                    case 7, 8, 16, 19, 20 -> in.skipNBytes(2);
                    case 9, 10, 11, 12, 17, 18 -> in.skipNBytes(4);
                    case 15 -> in.skipNBytes(3);
                    default -> throw new IllegalArgumentException("unknown constant-pool tag " + tag);
                }
            }
            in.skipNBytes(6);
            int interfaces = in.readUnsignedShort(); in.skipNBytes(2L * interfaces);
            skipMembers(in); // fields
            int methods = in.readUnsignedShort();
            List<String> result = new ArrayList<>();
            for (int i = 0; i < methods; i++) {
                in.readUnsignedShort();
                String name = utf[in.readUnsignedShort()];
                String descriptor = utf[in.readUnsignedShort()];
                int attributes = in.readUnsignedShort();
                for (int a = 0; a < attributes; a++) { in.readUnsignedShort(); in.skipNBytes(Integer.toUnsignedLong(in.readInt())); }
                if (wantedName.equals(name)) result.add(descriptor);
            }
            return result;
        }
    }

    private static void skipMembers(DataInputStream in) throws Exception {
        int count = in.readUnsignedShort();
        for (int i = 0; i < count; i++) {
            in.skipNBytes(6);
            int attributes = in.readUnsignedShort();
            for (int a = 0; a < attributes; a++) { in.skipNBytes(2); in.skipNBytes(Integer.toUnsignedLong(in.readInt())); }
        }
    }
}
