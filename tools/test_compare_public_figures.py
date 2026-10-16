import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

from compare_public_figures import compare


class RasterRegressionTests(unittest.TestCase):
    def test_identical_antialias_pass_and_visible_damage_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            a = Image.new('RGB', (600, 400), 'white')
            draw = ImageDraw.Draw(a)
            draw.rectangle((80, 50, 450, 330), outline='black', width=2)
            draw.rectangle((120, 180, 180, 328), fill='#527FAD')
            draw.rectangle((250, 120, 310, 328), fill='#B86D82')
            draw.rectangle((490, 100, 515, 118), fill='#527FAD')
            draw.text((490, 125), 'Control', fill='black')
            a.save(root / 'a.png')
            a.filter(ImageFilter.GaussianBlur(.25)).save(root / 'same.png')
            self.assertEqual(compare(root / 'a.png', root / 'same.png')['status'], 'PASS')
            for mode in ('blank', 'missing_legend', 'recolor', 'displaced'):
                b = a.copy()
                d = ImageDraw.Draw(b)
                if mode == 'blank':
                    d.rectangle((0, 0, 600, 400), fill='white')
                elif mode == 'missing_legend':
                    d.rectangle((480, 80, 599, 160), fill='white')
                elif mode == 'recolor':
                    d.rectangle((120, 180, 180, 328), fill='#E6BD27')
                    d.rectangle((250, 120, 310, 328), fill='#17CDB5')
                else:
                    b = ImageChops.offset(b, 35, 0)
                b.save(root / (mode + '.png'))
                self.assertEqual(compare(root / 'a.png', root / (mode + '.png'))['status'], 'FAIL', mode)


from PIL import ImageChops
if __name__ == '__main__':
    unittest.main()
