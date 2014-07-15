# language: en
Feature: Text Formatting
  In order to apply formatting to the text
  As a writer
  I want to be able to markup inline text with formatting characters


  Scenario: Render text that contains superscript and subscript characters
  Given the AsciiDoc source
    """
    _v_~rocket~ is the value
    ^3^He is the isotope
    log~4~x^n^ is the expression
    M^me^ White is the address
    the 10^th^ point has coordinate (x~10~, y~10~)
    """
  When it is converted to html
  Then the result should match the HTML source
    """
    <div class="paragraph">
    <p><em>v</em><sub>rocket</sub> is the value
    <sup>3</sup>He is the isotope
    log<sub>4</sub>x<sup>n</sup> is the expression
    M<sup>me</sup> White is the address
    the 10<sup>th</sup> point has coordinate (x<sub>10</sub>, y<sub>10</sub>)</p>
    </div>
    """
