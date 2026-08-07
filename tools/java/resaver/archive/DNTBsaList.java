package resaver.archive;

import java.nio.channels.FileChannel;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.regex.Pattern;

/** Minimal read-only BSA path lister built on ReSaver's archive parser. */
public final class DNTBsaList {
    private DNTBsaList() {}

    public static void main(String[] args) throws Exception {
        if (args.length != 2) {
            throw new IllegalArgumentException(
                "usage: DNTBsaList <archive.bsa> <path-regex>"
            );
        }

        Path archivePath = Paths.get(args[0]);
        Pattern selection = Pattern.compile(args[1], Pattern.CASE_INSENSITIVE);
        int matched = 0;
        try (
            FileChannel channel = FileChannel.open(archivePath, StandardOpenOption.READ);
            ArchiveParser parser = ArchiveParser.createParser(archivePath, channel)
        ) {
            if (!(parser instanceof BSAParser)) {
                throw new IllegalArgumentException("Expected a BSA archive");
            }
            BSAParser bsa = (BSAParser) parser;
            for (BSAFolderRecord folder : bsa.FOLDERRECORDS) {
                for (BSAFileRecord file : folder.FILERECORDS) {
                    Path filePath = file.getPath();
                    if (filePath == null) {
                        continue;
                    }
                    String normalized = folder.PATH.resolve(filePath)
                        .toString()
                        .replace('\\', '/');
                    if (selection.matcher(normalized).matches()) {
                        System.out.println(normalized);
                        matched++;
                    }
                }
            }
        }
        System.out.println("MATCHED=" + matched);
    }
}
