package resaver.archive;

import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.Optional;
import java.util.regex.Pattern;

/**
 * Minimal read-only BSA extractor built on ReSaver's installed archive parser.
 * The regular expression is matched against each archive-relative path.
 */
public final class DNTBsaExtract {
    private DNTBsaExtract() {}

    public static void main(String[] args) throws Exception {
        if (args.length != 3) {
            throw new IllegalArgumentException(
                "usage: DNTBsaExtract <archive.bsa> <output-dir> <path-regex>"
            );
        }

        Path archivePath = Paths.get(args[0]);
        Path outputRoot = Paths.get(args[1]);
        Pattern selection = Pattern.compile(args[2], Pattern.CASE_INSENSITIVE);
        Files.createDirectories(outputRoot);

        int matched = 0;
        try (
            FileChannel channel = FileChannel.open(
                archivePath,
                StandardOpenOption.READ
            );
            ArchiveParser parser = ArchiveParser.createParser(archivePath, channel)
        ) {
            if (parser == null) {
                throw new IllegalArgumentException("Unsupported archive: " + archivePath);
            }
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
                    Path archiveRelative = folder.PATH.resolve(filePath);
                    String normalized = archiveRelative.toString().replace('\\', '/');
                    if (!selection.matcher(normalized).matches()) {
                        continue;
                    }
                    Optional<ByteBuffer> value = BSAFileData.getData(
                        channel,
                        file,
                        bsa.HEADER
                    );
                    if (!value.isPresent()) {
                        throw new IllegalStateException("Could not read " + normalized);
                    }
                    Path outputPath = outputRoot.resolve(archiveRelative).normalize();
                    if (!outputPath.startsWith(outputRoot.normalize())) {
                        throw new IllegalStateException("Archive path escaped output root");
                    }
                    Files.createDirectories(outputPath.getParent());
                    ByteBuffer data = value.get();
                    byte[] bytes = new byte[data.remaining()];
                    data.get(bytes);
                    Files.write(outputPath, bytes);
                    System.out.println("EXTRACTED=" + normalized);
                    matched++;
                }
            }
        }
        System.out.println("MATCHED=" + matched);
    }
}
