#include <string>
#include <algorithm>
#include <vector>
#include <opencv2/opencv.hpp>
#include <opencv2/core/version.hpp>
#include <dirent.h>

// TODO
// Split into many files

template <std::ostream &Ostream, std::string &SrcFileName>
struct OstreamMsgWriter
{
  static std::ostream &start(const int line) noexcept
  {
    return Ostream << SrcFileName << ':' << line << ":: ";
  }
};


namespace
{

std::string ThisSrcFileName =
  (std::strrchr(__FILE__, '/') != NULL) ?
  (std::strrchr(__FILE__, '/') + 1) :
  __FILE__;

typedef OstreamMsgWriter<std::cout, ThisSrcFileName> InfoWriter;
typedef OstreamMsgWriter<std::cerr, ThisSrcFileName> ErrWriter;
} // anonymous namespace



bool getCellPosition(const std::string &fileName,
                           size_t      &colNumber,
                           size_t      &rowNumber) noexcept
{
  try
  {
    const std::string::size_type underlinePos = fileName.find('_', 0);
    const std::string::size_type pointPos     = fileName.find('.', underlinePos + 1);
    if (
           underlinePos == std::string::npos 
        || 
           pointPos == std::string::npos
        ||
           pointPos < underlinePos
       )
    {
      return false;
    }

  	const long colNumberSigned = std::atol(fileName.substr(0, underlinePos).c_str());
	  const long rowNumberSigned = std::atol(fileName.substr(underlinePos + 1,
                                                           pointPos - underlinePos - 1).c_str());
	  if ((colNumberSigned <= 0) || (rowNumberSigned <= 0))
  	{
      return false;
	  }
  	colNumber = colNumberSigned;
	  rowNumber = rowNumberSigned;
	  return true;
  }
  catch (...)
  {
    ErrWriter::start(__LINE__) << "something went wrong while parsing fileName = "
                               << fileName << '\n';                              
    return false;
  }
}

bool getMatrixParams(const std::string &imgDirPath,
                           size_t      &colCount,
                           size_t      &rowCount) noexcept
{
#define BAD_EXIT(LINE_NUM, MSG)                \
  do                                           \
  {                                            \
    ErrWriter::start(LINE_NUM) << MSG << '\n'; \
    return false;                              \
  }                                            \
  while (0);

  DIR *const ptDir = opendir(imgDirPath.c_str());
  if (ptDir == NULL)
  {
    BAD_EXIT(__LINE__, "couldn't read image dir.");
  }

  size_t maxColNumber = 0;
  size_t maxRowNumber = 0;
  bool oneImageMet = false;
  try
  {
    const struct dirent *ptDirent = NULL;
    while ((ptDirent = readdir(ptDir)) != NULL)
    {
      const std::string name(ptDirent->d_name);

      size_t colNumber = 0;
      size_t rowNumber = 0;
      if (!getCellPosition(name, colNumber, rowNumber))
      {
        continue;
      }
      else if (!oneImageMet)
      {
        oneImageMet = true;
      }

      maxColNumber = std::max<size_t>(maxColNumber, colNumber);
      maxRowNumber = std::max<size_t>(maxRowNumber, rowNumber);
    }
  }
  catch (...)
  {
    closedir(ptDir);
    BAD_EXIT(__LINE__, "Smth went wrong while walking through dir.");
  }

  closedir(ptDir);

  if (oneImageMet)
  {
    colCount = maxColNumber;
    rowCount = maxRowNumber;
    return true;
  }
  else
  {
    BAD_EXIT(__LINE__, "I did not find any suitable file.");
  }
#undef BAD_EXIT
}

bool getFileName(const std::string &imgDirPath,
                 const size_t       colNumber,
                 const size_t       rowNumber,
                       std::string &fileName) noexcept
{
#define BAD_EXIT(LINE_NUM, MSG)                \
  do                                           \
  {                                            \
    ErrWriter::start(LINE_NUM) << MSG << '\n'; \
    return false;                              \
  }                                            \
  while (0);

  DIR *const ptDir = opendir(imgDirPath.c_str());
  if (ptDir == NULL)
  {
    BAD_EXIT(__LINE__, "couldn't read image dir.");
  }

  try
  {
    const struct dirent *ptDirent = NULL;
    while ((ptDirent = readdir(ptDir)) != NULL)
    {
      const std::string currFileName(ptDirent->d_name);

      size_t currColNumber = 0;
      size_t currRowNumber = 0;
      if (!getCellPosition(currFileName, currColNumber, currRowNumber))
      {
        continue;
      }

      if ((currColNumber == colNumber) && (currRowNumber == rowNumber))
	  	{
		  	fileName = currFileName;
        closedir(ptDir);
			  return true;
  		}
    }
  }
  catch (...)
  {
    closedir(ptDir);
    BAD_EXIT(__LINE__, "something went wrong while walking through dir.");
  }

  closedir(ptDir);
  BAD_EXIT(__LINE__, "I did not find anything.");
#undef BAD_EXIT
}

bool concatFullImage(const std::string &outputFileName,
                     const std::string &inputImagesDir,
                     const size_t       colCount,
                     const size_t       rowCount)
{
// TODO
// Exceptions!!!
// Split into some functions

  InfoWriter::start(__LINE__) << "Working dir = " << inputImagesDir << '\n';
  std::vector<cv::Mat> wholeImageCup;
  wholeImageCup.reserve(rowCount);
  for (size_t y_coord = rowCount; y_coord > 0; --y_coord)
  {
    std::vector<cv::Mat> wholeRowImages;
    wholeRowImages.reserve(colCount);
    for (size_t x_coord = 1; x_coord <= colCount; ++x_coord)
    {
      std::string currFilename;
      if (!getFileName(inputImagesDir, x_coord, y_coord, currFilename))
      {
        ErrWriter::start(__LINE__) << "couldn't get file with coords ("
                                   << x_coord << ", " << y_coord << ").\n";
        return false;
      }
      InfoWriter::start(__LINE__) << '(' << x_coord << ", "
                                  << y_coord << ") image is " << currFilename
                                  << ", gonna read it.\n";
      std::string currFilePath = inputImagesDir;
      if (currFilePath[currFilePath.size() - 1] != '/')
      {
        currFilePath += '/';
      }
      currFilePath += currFilename;
      wholeRowImages.push_back(cv::imread(currFilePath));
      if (!wholeRowImages.back().data)
      {
        ErrWriter::start(__LINE__) << "Couldn't read image " 
                                   << currFilePath << ". Exiting...\n";
        return false;
      }
      InfoWriter::start(__LINE__) << '(' << x_coord << ", "
                                  << y_coord << ") image in file " << currFilePath
                                  << " has been successfully read.\n";
    }
    InfoWriter::start(__LINE__) << "Gonna concat images from row "
                                << y_coord << '\n';
    wholeImageCup.push_back(cv::Mat());
    cv::hconcat(wholeRowImages.data(), wholeRowImages.size(), wholeImageCup.back());
    if (!wholeImageCup.back().data)
    {
      ErrWriter::start(__LINE__) << "Concatenation of images from row "
                                 << y_coord << " failed. Exiting...\n";
      return false;
    }
    InfoWriter::start(__LINE__) << "Concatenation row " << y_coord << " finished.\n";
  }

  cv::Mat wholeImage;
  InfoWriter::start(__LINE__) << "Gonna vertical concat all rows.\n";
  cv::vconcat(wholeImageCup.data(), wholeImageCup.size(), wholeImage);
  if (!wholeImage.data)
  {
    ErrWriter::start(__LINE__) << "Concatenation of rows failed. Exiting...\n";
    return false;
  }
  InfoWriter::start(__LINE__) << "Concatenation of rows succeeded.\n";
  std::vector<int> compressionParams;
  compressionParams.push_back(CV_IMWRITE_JPEG_QUALITY);
  compressionParams.push_back(100);
  std::string outputImagePath = inputImagesDir;
  if (outputImagePath[outputImagePath.size() - 1] != '/')
  {
    outputImagePath += '/';
  }
  outputImagePath += outputFileName;
  InfoWriter::start(__LINE__) << "Gonna write whole image to file "
                              << outputImagePath << '\n';
  if (cv::imwrite(outputImagePath, wholeImage, compressionParams))
  {
    InfoWriter::start(__LINE__) << "Written successfully.\n";
    return true;
  }
  else
  {
    ErrWriter::start(__LINE__) << "Writting failed.\n";
    return false;
  }
}


int main(int argc, char** argv )
{
  if (argc != 3)
  {
    std::cerr << "Wrong program usage!\n"
                 "You should specify directory with tiles and output file name. "
                 "Output file will be put into directory with tiles.\n";

    return 1;
  }

  std::cout << "OpenCV version: " <<
    CV_VERSION_MAJOR << '.' <<
    CV_VERSION_MINOR << '.' <<
    CV_VERSION_REVISION << '\n';

  const std::string dirPath(argv[1]);
  size_t colCount = 0;
  size_t rowCount = 0;
  if (!getMatrixParams(dirPath, colCount, rowCount))
  {
    return 1;
  }
  std::cout << "colCount (x steps) = " << colCount << ", rowCount (y steps) = " << rowCount << '\n';

  const std::string fileName(argv[2]);
  return concatFullImage(fileName, dirPath, colCount, rowCount) ? 0 : 1;
}
